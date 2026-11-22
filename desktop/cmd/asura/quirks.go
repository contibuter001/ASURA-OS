package main

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"asura/hardware/match"
	"asura/hardware/probe"
)

// Model-specific hardware quirks system:
//   asura hardware quirks list
//   asura hardware quirks show [model-id]
//   asura hardware quirks apply [model-id]
//   asura hardware quirks remove [model-id]
//
// Matches laptops by DMI (/sys/class/dmi/id) and optional PCI IDs (e.g. GPU).
// Reads declarative data files in system/hardware/models/<vendor>-<model>.yaml.
// Data contains packages, modprobe/udev/sysctl files, kernel parameters,
// runit services, and notes. ASURA's code applies them safely; data never executes shell.

type QuirkModel struct {
	ID               string
	Name             string
	Description      string
	Match            QuirkMatch
	Packages         []string
	KernelParameters []string
	Files            []QuirkFile
	Services         []string
	Notes            []string
	FilePath         string
}

type QuirkMatch struct {
	SysVendor     string
	ProductName   string
	ProductFamily string
	BoardName     string
	Chassis       string // "laptop", "desktop", etc.
	GPU           string // e.g. "10de:25a2"
}

type QuirkFile struct {
	Kind    string // "udev", "modprobe", "sysctl"
	Target  string
	Source  string
	Content string
	Reason  string
}

var (
	quirksAppliedStateFile = "/var/lib/asura/quirks.applied"
	quirksPrivileged       = runPrivileged
)

// resolveModelsDir finds the models directory.
func resolveModelsDir() string {
	candidates := []string{
		"/usr/share/asura/hardware/models",
		"system/hardware/models",
		"../system/hardware/models",
		"../../system/hardware/models",
		"../../../system/hardware/models",
	}
	for _, dir := range candidates {
		if info, err := os.Stat(dir); err == nil && info.IsDir() {
			return dir
		}
	}
	return "system/hardware/models"
}

// parseQuirkModel parses a model quirk YAML file without external dependencies.
func parseQuirkModel(data []byte, path string) (QuirkModel, error) {
	scanner := bufio.NewScanner(bytes.NewReader(data))
	model := QuirkModel{
		FilePath: path,
	}

	section := ""
	subSection := ""
	var currentFile *QuirkFile

	flushCurrentFile := func() {
		if currentFile != nil && currentFile.Target != "" {
			model.Files = append(model.Files, *currentFile)
			currentFile = nil
		}
	}

	inMultilineContent := false
	var contentBuilder strings.Builder

	for scanner.Scan() {
		rawLine := scanner.Text()
		trimmed := strings.TrimSpace(rawLine)

		if inMultilineContent {
			indent := len(rawLine) - len(strings.TrimLeft(rawLine, " "))
			if indent >= 8 && trimmed != "" {
				contentBuilder.WriteString(rawLine[8:])
				contentBuilder.WriteString("\n")
				continue
			}
			inMultilineContent = false
			if currentFile != nil {
				currentFile.Content = contentBuilder.String()
			}
			contentBuilder.Reset()
		}

		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		indent := len(rawLine) - len(strings.TrimLeft(rawLine, " "))

		// Top-level sections (indent == 0)
		if indent == 0 {
			flushCurrentFile()
			key, val, found := strings.Cut(trimmed, ":")
			if !found {
				continue
			}
			key = strings.TrimSpace(key)
			val = strings.Trim(strings.TrimSpace(val), "\"'")

			section = key
			subSection = ""
			switch key {
			case "id":
				model.ID = val
			case "name":
				model.Name = val
			case "description":
				model.Description = val
			}
			continue
		}

		// Indented level
		switch section {
		case "match":
			key, val, found := strings.Cut(trimmed, ":")
			if found {
				key = strings.TrimSpace(key)
				val = strings.Trim(strings.TrimSpace(val), "\"'")
				switch key {
				case "sys_vendor":
					model.Match.SysVendor = val
				case "product_name":
					model.Match.ProductName = val
				case "product_family":
					model.Match.ProductFamily = val
				case "board_name":
					model.Match.BoardName = val
				case "chassis", "chassis_type":
					model.Match.Chassis = val
				case "gpu":
					model.Match.GPU = val
				}
			}
		case "packages":
			if strings.HasPrefix(trimmed, "- ") {
				pkg := strings.Trim(strings.TrimSpace(trimmed[2:]), "\"'")
				if pkg != "" {
					model.Packages = append(model.Packages, pkg)
				}
			}
		case "kernel_parameters":
			if strings.HasPrefix(trimmed, "- ") {
				param := strings.Trim(strings.TrimSpace(trimmed[2:]), "\"'")
				if param != "" {
					model.KernelParameters = append(model.KernelParameters, param)
				}
			}
		case "services":
			if strings.HasPrefix(trimmed, "- ") {
				svc := strings.Trim(strings.TrimSpace(trimmed[2:]), "\"'")
				if svc != "" {
					model.Services = append(model.Services, svc)
				}
			}
		case "notes":
			if strings.HasPrefix(trimmed, "- ") {
				note := strings.Trim(strings.TrimSpace(trimmed[2:]), "\"'")
				if note != "" {
					model.Notes = append(model.Notes, note)
				}
			}
		case "files":
			if indent == 2 {
				flushCurrentFile()
				key, _, _ := strings.Cut(trimmed, ":")
				subSection = strings.TrimSpace(key)
				continue
			}
			if strings.HasPrefix(trimmed, "- target:") {
				flushCurrentFile()
				targetVal := strings.Trim(strings.TrimSpace(strings.TrimPrefix(trimmed, "- target:")), "\"'")
				currentFile = &QuirkFile{
					Kind:   subSection,
					Target: targetVal,
				}
				continue
			}
			if currentFile != nil {
				key, val, found := strings.Cut(trimmed, ":")
				if found {
					key = strings.TrimSpace(key)
					val = strings.TrimSpace(val)
					switch key {
					case "source":
						currentFile.Source = strings.Trim(val, "\"'")
					case "reason":
						currentFile.Reason = strings.Trim(val, "\"'")
					case "content":
						if val == "|" || val == ">" {
							inMultilineContent = true
							contentBuilder.Reset()
						} else {
							currentFile.Content = strings.Trim(val, "\"'")
						}
					}
				}
			}
		}
	}
	flushCurrentFile()

	if model.ID == "" {
		model.ID = strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	}
	return model, nil
}

// loadQuirkModels loads all quirk models from the models directory.
func loadQuirkModels(dir string) ([]QuirkModel, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}

	var models []QuirkModel
	for _, entry := range entries {
		if entry.IsDir() || (!strings.HasSuffix(entry.Name(), ".yaml") && !strings.HasSuffix(entry.Name(), ".yml")) {
			continue
		}
		path := filepath.Join(dir, entry.Name())
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		model, err := parseQuirkModel(data, path)
		if err == nil && model.ID != "" {
			models = append(models, model)
		}
	}
	return models, nil
}

func isLaptopChassis(chassis string) bool {
	c := strings.ToLower(strings.TrimSpace(chassis))
	switch c {
	case "laptop", "notebook", "portable", "sub-notebook", "convertible", "detachable":
		return true
	}
	return false
}

func matchFieldPattern(pattern, value string) bool {
	if pattern == "" || pattern == "*" {
		return true
	}
	p := strings.ToLower(strings.TrimSpace(pattern))
	v := strings.ToLower(strings.TrimSpace(value))
	if p == v {
		return true
	}
	if matched, _ := filepath.Match(p, v); matched {
		return true
	}
	if strings.Contains(p, "*") {
		trimmedPat := strings.Trim(p, "*")
		if trimmedPat != "" && strings.Contains(v, trimmedPat) {
			return true
		}
	}
	normP := match.Normalize(pattern)
	normV := match.Normalize(value)
	if normP != "" && normV != "" {
		if normP == normV || strings.HasPrefix(normV, normP) || strings.HasPrefix(normP, normV) {
			return true
		}
	}
	return false
}

// quirkSpecificity calculates the specificity score of a quirk model for ranking.
func quirkSpecificity(model QuirkModel) int {
	score := 0
	if model.Match.ProductName != "" && model.Match.ProductName != "*" {
		score += 100
	}
	if model.Match.BoardName != "" && model.Match.BoardName != "*" {
		score += 50
	}
	if model.Match.GPU != "" && model.Match.GPU != "*" {
		score += 40
	}
	if model.Match.ProductFamily != "" && model.Match.ProductFamily != "*" {
		score += 25
	}
	if model.Match.SysVendor != "" && model.Match.SysVendor != "*" {
		score += 10
	}
	if model.Match.Chassis != "" {
		score += 1
	}
	return score
}

// matchQuirkModel checks if a model matches the machine DMI, Chassis, and PCI IDs.
func matchQuirkModel(model QuirkModel, dmi probe.Fields, pciDevices []probe.Device) bool {
	// Chassis matching
	if model.Match.Chassis != "" {
		req := strings.ToLower(strings.TrimSpace(model.Match.Chassis))
		if req == "laptop" || req == "notebook" {
			if !isLaptopChassis(dmi.ChassisType) {
				return false
			}
		} else if !matchFieldPattern(model.Match.Chassis, dmi.ChassisType) {
			return false
		}
	}

	// DMI matching
	if model.Match.SysVendor != "" {
		if !matchFieldPattern(model.Match.SysVendor, dmi.SysVendor) {
			return false
		}
	}
	if model.Match.ProductName != "" {
		if !matchFieldPattern(model.Match.ProductName, dmi.ProductName) {
			return false
		}
	}
	if model.Match.ProductFamily != "" {
		if !matchFieldPattern(model.Match.ProductFamily, dmi.ProductFamily) {
			return false
		}
	}
	if model.Match.BoardName != "" {
		if !matchFieldPattern(model.Match.BoardName, dmi.BoardName) {
			return false
		}
	}

	// PCI matching (optional)
	if model.Match.GPU != "" {
		normGPU := strings.ToLower(strings.TrimSpace(model.Match.GPU))
		matchedGPU := false
		for _, dev := range pciDevices {
			v := strings.TrimPrefix(strings.ToLower(dev.Vendor), "0x")
			d := strings.TrimPrefix(strings.ToLower(dev.Device), "0x")
			id := v + ":" + d
			if id == normGPU {
				matchedGPU = true
				break
			}
		}
		if !matchedGPU {
			return false
		}
	}

	return true
}

// findMatchedQuirkModel finds the model quirk matching this machine with highest specificity.
func findMatchedQuirkModel(models []QuirkModel, root string) *QuirkModel {
	fs, err := probe.New(root)
	if err != nil {
		return nil
	}
	dmi, err := probe.DMI(fs)
	if err != nil {
		return nil
	}
	pciDevices, _ := probe.PCI(fs, nil)

	var matched []QuirkModel
	for _, m := range models {
		if matchQuirkModel(m, dmi, pciDevices) {
			matched = append(matched, m)
		}
	}
	if len(matched) == 0 {
		return nil
	}

	bestIdx := 0
	bestScore := quirkSpecificity(matched[0])
	for i := 1; i < len(matched); i++ {
		score := quirkSpecificity(matched[i])
		if score > bestScore {
			bestScore = score
			bestIdx = i
		}
	}

	chosen := matched[bestIdx]
	return &chosen
}

const quirksUsage = `Usage: asura hardware quirks [list | show | apply | remove]

Manages model-specific hardware fixes and device tuning.

  list            list available model quirks and highlight matches for this machine
  show [model-id] display configuration and tuning plan for a model
  apply [model-id]apply model fixes (creates a system snapshot first)
  remove [model-id]revert applied model fixes
`

func hardwareQuirks(args []string) int {
	if len(args) == 0 || args[0] == "list" {
		return runQuirksList()
	}

	switch args[0] {
	case "list":
		return runQuirksList()
	case "show":
		return runQuirksShow(args[1:])
	case "apply":
		return runQuirksApply(args[1:])
	case "remove":
		return runQuirksRemove(args[1:])
	case "-h", "--help", "help":
		fmt.Print(quirksUsage)
		return exitOK
	default:
		fmt.Fprintf(os.Stderr, "asura hardware quirks: unknown verb %q\n\n%s", args[0], quirksUsage)
		return exitUsage
	}
}

func runQuirksList() int {
	dir := resolveModelsDir()
	models, err := loadQuirkModels(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "asura hardware quirks: %v\n", err)
		return exitFail
	}

	matched := findMatchedQuirkModel(models, "")
	appliedID := getAppliedQuirkID()

	fmt.Printf("Model Hardware Quirks (%d definition(s) in %s):\n\n", len(models), dir)
	for _, m := range models {
		tag := ""
		if matched != nil && matched.ID == m.ID {
			if appliedID == m.ID {
				tag = " [MATCHES THIS MACHINE, APPLIED]"
			} else {
				tag = " [MATCHES THIS MACHINE]"
			}
		} else if appliedID == m.ID {
			tag = " [APPLIED]"
		}
		fmt.Printf("  %-25s %s%s\n", m.ID, m.Name, tag)
	}
	fmt.Println()
	if matched != nil && appliedID != matched.ID {
		fmt.Printf("Run 'asura hardware quirks apply' to apply fixes for %s.\n", matched.Name)
	}
	return exitOK
}

func runQuirksShow(args []string) int {
	dir := resolveModelsDir()
	models, err := loadQuirkModels(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "asura hardware quirks: %v\n", err)
		return exitFail
	}

	var target *QuirkModel
	if len(args) > 0 {
		targetID := args[0]
		for _, m := range models {
			if m.ID == targetID {
				cp := m
				target = &cp
				break
			}
		}
		if target == nil {
			fmt.Fprintf(os.Stderr, "asura hardware quirks: model %q not found\n", targetID)
			return exitFail
		}
	} else {
		target = findMatchedQuirkModel(models, "")
		if target == nil {
			fmt.Println("No specific model quirks match this machine.")
			return exitOK
		}
	}

	fmt.Printf("Model:       %s (%s)\n", target.Name, target.ID)
	fmt.Printf("Description: %s\n", target.Description)
	fmt.Println()

	fmt.Println("DMI Match Criteria:")
	if target.Match.SysVendor != "" {
		fmt.Printf("  sys_vendor:     %s\n", target.Match.SysVendor)
	}
	if target.Match.ProductName != "" {
		fmt.Printf("  product_name:   %s\n", target.Match.ProductName)
	}
	if target.Match.ProductFamily != "" {
		fmt.Printf("  product_family: %s\n", target.Match.ProductFamily)
	}
	if target.Match.BoardName != "" {
		fmt.Printf("  board_name:     %s\n", target.Match.BoardName)
	}
	if target.Match.GPU != "" {
		fmt.Printf("  gpu (pci):      %s\n", target.Match.GPU)
	}
	fmt.Println()

	if len(target.Packages) > 0 {
		fmt.Println("Packages:")
		for _, p := range target.Packages {
			fmt.Printf("  - %s\n", p)
		}
		fmt.Println()
	}

	if len(target.KernelParameters) > 0 {
		fmt.Println("Kernel Parameters:")
		for _, kp := range target.KernelParameters {
			fmt.Printf("  - %s\n", kp)
		}
		fmt.Println()
	}

	if len(target.Files) > 0 {
		fmt.Println("Configuration Files:")
		for _, f := range target.Files {
			fmt.Printf("  - %s (%s): %s\n", f.Target, f.Kind, f.Reason)
		}
		fmt.Println()
	}

	if len(target.Notes) > 0 {
		fmt.Println("Hardware Notes:")
		for _, n := range target.Notes {
			fmt.Printf("  * %s\n", n)
		}
	}

	return exitOK
}

func runQuirksApply(args []string) int {
	dir := resolveModelsDir()
	models, err := loadQuirkModels(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "asura hardware quirks: %v\n", err)
		return exitFail
	}

	var target *QuirkModel
	if len(args) > 0 {
		for _, m := range models {
			if m.ID == args[0] {
				cp := m
				target = &cp
				break
			}
		}
		if target == nil {
			fmt.Fprintf(os.Stderr, "asura hardware quirks: model %q not found\n", args[0])
			return exitFail
		}
	} else {
		target = findMatchedQuirkModel(models, "")
		if target == nil {
			fmt.Println("No model quirks match this machine.")
			return exitOK
		}
	}

	fmt.Printf("Applying hardware quirks for %s...\n", target.Name)

	// Pre-apply snapshot
	if isBtrfsRoot() {
		fmt.Println("Taking pre-quirk system snapshot...")
		if snap, err := createBtrfsSnapshotAs(snapshotManual); err == nil {
			fmt.Printf("Created snapshot %s before applying quirks.\n", snap)
		}
	}

	// Install packages
	for _, pkg := range target.Packages {
		if !svInstalled(pkg) {
			fmt.Printf("Installing %s...\n", pkg)
			_ = quirksPrivileged("xbps-install", "-Sy", pkg)
		}
	}

	// Install files with backup
	for _, f := range target.Files {
		var content []byte
		if f.Content != "" {
			content = []byte(f.Content)
		} else if f.Source != "" {
			if data, err := os.ReadFile(f.Source); err == nil {
				content = data
			} else if data, err := os.ReadFile(filepath.Join("..", f.Source)); err == nil {
				content = data
			}
		}

		if len(content) == 0 {
			continue
		}

		// Keep backup if target exists
		if orig, err := os.ReadFile(f.Target); err == nil {
			bak := f.Target + ".asura-quirk-bak"
			if _, err := os.Stat(bak); os.IsNotExist(err) {
				_ = os.WriteFile(bak, orig, 0644)
			}
		}

		_ = os.MkdirAll(filepath.Dir(f.Target), 0755)
		tmp := filepath.Join(os.TempDir(), "quirk-"+filepath.Base(f.Target))
		if err := os.WriteFile(tmp, content, 0644); err == nil {
			_ = quirksPrivileged("cp", tmp, f.Target)
			_ = os.Remove(tmp)
			fmt.Printf("Laid down %s: %s\n", f.Target, f.Reason)
		}
	}

	// Update kernel parameters in GRUB if any
	if len(target.KernelParameters) > 0 {
		applyGrubKernelParameters(target.KernelParameters)
	}

	// Reload udev rules
	_ = quirksPrivileged("udevadm", "control", "--reload-rules")
	_ = quirksPrivileged("udevadm", "trigger")

	// Record applied quirk ID
	_ = os.MkdirAll(filepath.Dir(quirksAppliedStateFile), 0755)
	_ = os.WriteFile(quirksAppliedStateFile, []byte(target.ID+"\n"), 0644)

	fmt.Printf("Successfully applied hardware quirks for %s.\n", target.Name)
	return exitOK
}

func runQuirksRemove(args []string) int {
	appliedID := getAppliedQuirkID()
	if appliedID == "" && len(args) == 0 {
		fmt.Println("No hardware quirks are currently applied.")
		return exitOK
	}

	dir := resolveModelsDir()
	models, _ := loadQuirkModels(dir)
	var target *QuirkModel
	for _, m := range models {
		if (len(args) > 0 && m.ID == args[0]) || (len(args) == 0 && m.ID == appliedID) {
			cp := m
			target = &cp
			break
		}
	}

	if target != nil {
		fmt.Printf("Removing hardware quirks for %s...\n", target.Name)
		for _, f := range target.Files {
			bak := f.Target + ".asura-quirk-bak"
			if _, err := os.Stat(bak); err == nil {
				_ = quirksPrivileged("cp", bak, f.Target)
				_ = quirksPrivileged("rm", "-f", bak)
				fmt.Printf("Restored %s from backup\n", f.Target)
			} else {
				_ = quirksPrivileged("rm", "-f", f.Target)
				fmt.Printf("Removed %s\n", f.Target)
			}
		}
		if len(target.KernelParameters) > 0 {
			removeGrubKernelParameters(target.KernelParameters)
		}
	}

	_ = quirksPrivileged("udevadm", "control", "--reload-rules")
	_ = quirksPrivileged("udevadm", "trigger")
	_ = os.Remove(quirksAppliedStateFile)

	fmt.Println("Hardware quirks removed.")
	return exitOK
}

func getAppliedQuirkID() string {
	data, err := os.ReadFile(quirksAppliedStateFile)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func updateGrubCmdlineParams(content string, params []string, add bool) string {
	paramSet := map[string]bool{}
	for _, p := range params {
		paramSet[p] = true
	}

	re := regexp.MustCompile(`(?m)^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)(")`)
	return re.ReplaceAllStringFunc(content, func(m string) string {
		match := re.FindStringSubmatch(m)
		opts := strings.Fields(match[2])
		if add {
			optSet := map[string]bool{}
			for _, opt := range opts {
				optSet[opt] = true
			}
			for _, p := range params {
				if !optSet[p] {
					opts = append(opts, p)
				}
			}
			return match[1] + strings.Join(opts, " ") + match[3]
		}
		// remove
		filtered := []string{}
		for _, opt := range opts {
			if !paramSet[opt] {
				filtered = append(filtered, opt)
			}
		}
		return match[1] + strings.Join(filtered, " ") + match[3]
	})
}

func applyGrubKernelParameters(params []string) {
	data, err := os.ReadFile(hibernateGrubDefault)
	if err != nil {
		return
	}
	content := string(data)
	updated := updateGrubCmdlineParams(content, params, true)

	if updated != content {
		tmp := filepath.Join(os.TempDir(), "grub-quirks")
		if err := os.WriteFile(tmp, []byte(updated), 0644); err == nil {
			_ = quirksPrivileged("cp", tmp, hibernateGrubDefault)
			_ = os.Remove(tmp)
			_ = quirksPrivileged("update-grub")
		}
	}
}

func removeGrubKernelParameters(params []string) {
	data, err := os.ReadFile(hibernateGrubDefault)
	if err != nil {
		return
	}
	content := string(data)
	updated := updateGrubCmdlineParams(content, params, false)

	if updated != content {
		tmp := filepath.Join(os.TempDir(), "grub-quirks-clean")
		if err := os.WriteFile(tmp, []byte(updated), 0644); err == nil {
			_ = quirksPrivileged("cp", tmp, hibernateGrubDefault)
			_ = os.Remove(tmp)
			_ = quirksPrivileged("update-grub")
		}
	}
}
