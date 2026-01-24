#!/usr/bin/env bats
# pimpmytmux - Tests for lib/preview.sh

load 'test_helper'

setup() {
    mkdir -p "$PIMPMYTMUX_CONFIG_DIR"
    mkdir -p "$PIMPMYTMUX_DATA_DIR"
    mkdir -p "$PIMPMYTMUX_CACHE_DIR"

    # Load libraries
    load_lib 'core'
    load_lib 'config'
    load_lib 'preview'
}

# -----------------------------------------------------------------------------
# Theme preview tests
# -----------------------------------------------------------------------------

@test "preview_theme_colors displays color swatches" {
    run preview_theme_colors "cyberpunk"
    assert_success
    # Should contain color names
    assert_output_contains "bg"
    assert_output_contains "fg"
    assert_output_contains "accent"
}

@test "preview_theme_colors handles missing theme" {
    run preview_theme_colors "nonexistent_theme"
    assert_failure
    assert_output_contains "Theme not found"
}

@test "preview_theme_palette displays full palette" {
    run preview_theme_palette "matrix"
    assert_success
    # Should show all color types
    assert_output_contains "accent"
}

@test "preview_theme_statusbar shows status bar example" {
    run preview_theme_statusbar "dracula"
    assert_success
    # Should contain status bar header
    assert_output_contains "Status bar preview"
}

@test "get_theme_file returns correct path for theme name" {
    result=$(get_theme_file "cyberpunk")
    [[ "$result" == *"themes/cyberpunk.yaml" ]]
}

@test "get_theme_file returns input if already a path" {
    result=$(get_theme_file "/path/to/custom.yaml")
    [[ "$result" == "/path/to/custom.yaml" ]]
}

@test "get_theme_colors extracts colors from theme" {
    run get_theme_colors "cyberpunk"
    assert_success
    # Should output color definitions
    [[ "$output" =~ "#" ]]
}

# -----------------------------------------------------------------------------
# Layout preview tests
# -----------------------------------------------------------------------------

@test "preview_layout_ascii displays ASCII diagram" {
    run preview_layout_ascii "dev-fullstack"
    assert_success
    # Should contain box drawing characters or representation
    [[ "$output" =~ (┌|├|─|\||\+) ]]
}

@test "preview_layout_ascii handles missing layout" {
    run preview_layout_ascii "nonexistent_layout"
    assert_failure
    assert_output_contains "Layout not found"
}

@test "preview_layout_details shows layout info" {
    run preview_layout_details "dev-fullstack"
    assert_success
    # Should show name and description
    assert_output_contains "Dev Fullstack"
}

@test "preview_layout_panes lists all panes" {
    run preview_layout_panes "dev-fullstack"
    assert_success
    # Should list pane names
    assert_output_contains "editor"
}

@test "get_layout_file returns correct path" {
    result=$(get_layout_file "dev-fullstack")
    [[ "$result" == *"templates/dev-fullstack.yaml" ]]
}

# -----------------------------------------------------------------------------
# Config diff preview tests
# -----------------------------------------------------------------------------

@test "preview_config_diff shows changes" {
    # Create a test config
    create_test_config 'theme: cyberpunk'

    # Create a modified config
    local new_config="${PIMPMYTMUX_TEST_DIR}/new_config.yaml"
    echo "theme: matrix" > "$new_config"

    run preview_config_diff "$new_config"
    # Should show some kind of diff
    assert_success
}

@test "preview_config_diff handles missing current config" {
    local new_config="${PIMPMYTMUX_TEST_DIR}/new_config.yaml"
    echo "theme: matrix" > "$new_config"

    # Remove current config
    rm -f "${PIMPMYTMUX_CONFIG_DIR}/pimpmytmux.yaml"

    run preview_config_diff "$new_config"
    # Should still succeed showing new config
    assert_success
}

# -----------------------------------------------------------------------------
# Color output tests
# -----------------------------------------------------------------------------

@test "print_color_swatch displays colored block" {
    run print_color_swatch "#ff0000" "red"
    assert_success
    assert_output_contains "red"
}

@test "hex_to_rgb converts hex to RGB" {
    result=$(hex_to_rgb "#ff0000")
    [[ "$result" == "255;0;0" ]]
}

@test "hex_to_rgb handles short hex" {
    result=$(hex_to_rgb "#f00")
    [[ "$result" == "255;0;0" ]]
}

@test "rgb_to_ansi creates ANSI escape code" {
    result=$(rgb_to_ansi "255" "0" "0")
    # Should contain ANSI escape sequence
    [[ "$result" =~ "\033" ]] || [[ "$result" =~ "\\033" ]]
}

# -----------------------------------------------------------------------------
# Integration tests
# -----------------------------------------------------------------------------

@test "preview_theme shows complete theme preview" {
    run preview_theme "cyberpunk"
    assert_success
    # Should contain theme name and colors
    assert_output_contains "Cyberpunk"
}

@test "preview_layout shows complete layout preview" {
    run preview_layout "dev-fullstack"
    assert_success
    # Should contain layout info and ASCII
    assert_output_contains "Dev Fullstack"
}
