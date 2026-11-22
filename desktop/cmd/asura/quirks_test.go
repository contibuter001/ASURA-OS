package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"asura/hardware/probe"
)

func TestParseQuirkModel(t *testing.T) {
	yamlContent := []byte(`id: test-laptop
name: "Test Laptop 15"
description: "Test description"

match:
  sys_vendor: "TestVendor"
  product_name: "TestProduct"
  product_family: "TestFamily"
  board_name: "TestBoard"
  chassis: "laptop"
  pci:
    gpu: "10de:1234"

packages:
  - pkg1
  - pkg2

kernel_parameters:
  - "param1=val"
  - "param2"

files:
  udev:
    - target: "/etc/udev/rules.d/99-test.rules"
      content: |
        # rule 1
        SUBSYSTEM=="power", ACTION=="add"
      reason: "test rule"
  modprobe:
    - target: "/etc/modprobe.d/test.conf"
      source: "system/modprobe.d/test.conf"
      reason: "test modprobe"

notes:
  - "note 1"
  - "note 2"
`)

	model, err := parseQuirkModel(yamlContent, "test.yaml")
	if err != nil {
		t.Fatalf("parseQuirkModel error: %v", err)
	}

	if model.ID != "test-laptop" {
		t.Errorf("ID = %q, want test-laptop", model.ID)
	}
	if model.Name != "Test Laptop 15" {
		t.Errorf("Name = %q, want Test Laptop 15", model.Name)
	}
	if model.Match.SysVendor != "TestVendor" {
		t.Errorf("SysVendor = %q, want TestVendor", model.Match.SysVendor)
	}
	if model.Match.Chassis != "laptop" {
		t.Errorf("Chassis = %q, want laptop", model.Match.Chassis)
	}
	if model.Match.GPU != "10de:1234" {
		t.Errorf("GPU = %q, want 10de:1234", model.Match.GPU)
	}
	if len(model.Packages) != 2 || model.Packages[0] != "pkg1" {
		t.Errorf("Packages = %+v, want [pkg1, pkg2]", model.Packages)
	}
	if len(model.KernelParameters) != 2 || model.KernelParameters[0] != "param1=val" {
		t.Errorf("KernelParameters = %+v, want [param1=val, param2]", model.KernelParameters)
	}
	if len(model.Files) != 2 {
		t.Fatalf("Files len = %d, want 2", len(model.Files))
	}
	if model.Files[0].Target != "/etc/udev/rules.d/99-test.rules" {
		t.Errorf("Files[0].Target = %q", model.Files[0].Target)
	}
	if !strings.Contains(model.Files[0].Content, "SUBSYSTEM==\"power\"") {
		t.Errorf("Files[0].Content = %q", model.Files[0].Content)
	}
	if len(model.Notes) != 2 {
		t.Errorf("Notes len = %d, want 2", len(model.Notes))
	}
}

func TestMatchQuirkModel_Specificity(t *testing.T) {
	modelsDir := resolveModelsDir()
	if _, err := os.Stat(modelsDir); err != nil {
		modelsDir = "../../../system/hardware/models"
	}
	models, err := loadQuirkModels(modelsDir)
	if err != nil {
		t.Fatalf("failed to load models from %s: %v", modelsDir, err)
	}

	// 1. ASUS TUF FX507ZC4 machine
	tufDMI := probe.Fields{
		SysVendor:     "ASUSTeK COMPUTER INC.",
		ProductName:   "ASUS TUF Gaming F15 FX507ZC4_FX507ZC4",
		ProductFamily: "ASUS TUF Gaming F15",
		BoardName:     "FX507ZC4",
		ChassisType:   "notebook",
	}
	tufPCI := []probe.Device{
		{Vendor: "0x10de", Device: "0x25a2"},
	}

	matchedTuf := matchAllModels(models, tufDMI, tufPCI)
	if len(matchedTuf) < 2 {
		t.Fatalf("expected at least 2 models matching TUF machine, got %d", len(matchedTuf))
	}
	bestTuf := findBestModel(matchedTuf)
	if bestTuf.ID != "asus-tuf-fx507zc4" {
		t.Errorf("best match for TUF machine = %q, want asus-tuf-fx507zc4", bestTuf.ID)
	}

	// 2. Lenovo ThinkPad T14 Gen 3
	thinkpadDMI := probe.Fields{
		SysVendor:     "LENOVO",
		ProductName:   "21AH000EUS",
		ProductFamily: "ThinkPad T14 Gen 3",
		ChassisType:   "notebook",
	}
	matchedThinkPad := matchAllModels(models, thinkpadDMI, nil)
	bestThinkPad := findBestModel(matchedThinkPad)
	if bestThinkPad.ID != "lenovo-thinkpad" {
		t.Errorf("best match for ThinkPad = %q, want lenovo-thinkpad", bestThinkPad.ID)
	}

	// 3. Dell XPS 15
	xpsDMI := probe.Fields{
		SysVendor:     "Dell Inc.",
		ProductName:   "XPS 15 9520",
		ProductFamily: "XPS 15",
		ChassisType:   "laptop",
	}
	matchedXPS := matchAllModels(models, xpsDMI, nil)
	bestXPS := findBestModel(matchedXPS)
	if bestXPS.ID != "dell-xps" {
		t.Errorf("best match for XPS = %q, want dell-xps", bestXPS.ID)
	}

	// 4. Random unlisted laptop (Tongfang / Clevo)
	clevoDMI := probe.Fields{
		SysVendor:     "Clevo",
		ProductName:   "NH50",
		ProductFamily: "NH Series",
		ChassisType:   "notebook",
	}
	matchedClevo := matchAllModels(models, clevoDMI, nil)
	bestClevo := findBestModel(matchedClevo)
	if bestClevo == nil || bestClevo.ID != "generic-laptop" {
		t.Errorf("best match for Clevo = %+v, want generic-laptop", bestClevo)
	}

	// 5. Desktop ATX Tower
	desktopDMI := probe.Fields{
		SysVendor:     "Micro-Star International Co., Ltd.",
		ProductName:   "MS-7C37",
		ProductFamily: "Custom Desktop",
		ChassisType:   "desktop",
	}
	matchedDesktop := matchAllModels(models, desktopDMI, nil)
	if len(matchedDesktop) != 0 {
		t.Errorf("desktop machine matched %d laptop profiles: %+v, want 0", len(matchedDesktop), matchedDesktop)
	}
}

func matchAllModels(models []QuirkModel, dmi probe.Fields, pci []probe.Device) []QuirkModel {
	var res []QuirkModel
	for _, m := range models {
		if matchQuirkModel(m, dmi, pci) {
			res = append(res, m)
		}
	}
	return res
}

func findBestModel(models []QuirkModel) *QuirkModel {
	if len(models) == 0 {
		return nil
	}
	bestIdx := 0
	bestScore := quirkSpecificity(models[0])
	for i := 1; i < len(models); i++ {
		score := quirkSpecificity(models[i])
		if score > bestScore {
			bestScore = score
			bestIdx = i
		}
	}
	chosen := models[bestIdx]
	return &chosen
}

func TestGrubKernelParameters(t *testing.T) {
	tempDir := t.TempDir()
	grubPath := filepath.Join(tempDir, "grub")

	initial := `GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Asura"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 quiet"
`
	if err := os.WriteFile(grubPath, []byte(initial), 0644); err != nil {
		t.Fatal(err)
	}

	// Add params
	params := []string{"nvidia-drm.modeset=1", "mem_sleep_default=deep"}
	data, _ := os.ReadFile(grubPath)
	updated := updateGrubCmdlineParams(string(data), params, true)
	_ = os.WriteFile(grubPath, []byte(updated), 0644)

	afterAdd, _ := os.ReadFile(grubPath)
	if !strings.Contains(string(afterAdd), "nvidia-drm.modeset=1") || !strings.Contains(string(afterAdd), "mem_sleep_default=deep") {
		t.Errorf("grub cmdline missing params after add: %s", string(afterAdd))
	}

	// Remove params
	data, _ = os.ReadFile(grubPath)
	updated = updateGrubCmdlineParams(string(data), params, false)
	_ = os.WriteFile(grubPath, []byte(updated), 0644)

	afterRemove, _ := os.ReadFile(grubPath)
	if strings.Contains(string(afterRemove), "nvidia-drm.modeset=1") || strings.Contains(string(afterRemove), "mem_sleep_default=deep") {
		t.Errorf("grub cmdline still has params after remove: %s", string(afterRemove))
	}
	if !strings.Contains(string(afterRemove), "loglevel=4 quiet") {
		t.Errorf("original params lost: %s", string(afterRemove))
	}
}
