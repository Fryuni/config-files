{ lib, ... }:
let
  toINI = lib.generators.toINI { };
in
{
  home.file.".config/xfce4/terminal/terminalrc".text = toINI {
    Configuration = {
      FontName = "FiraCode Nerd Font weight=450 12";
      MiscAlwaysShowTabs = "FALSE";
      MiscBell = "FALSE";
      MiscBellUrgent = "FALSE";
      MiscBordersDefault = "TRUE";
      MiscCursorBlinks = "FALSE";
      MiscCursorShape = "TERMINAL_CURSOR_SHAPE_BLOCK";
      MiscDefaultGeometry = "160x48";
      MiscInheritGeometry = "FALSE";
      MiscMenubarDefault = "TRUE";
      MiscMouseAutohide = "FALSE";
      MiscMouseWheelZoom = "TRUE";
      MiscToolbarDefault = "FALSE";
      MiscConfirmClose = "TRUE";
      MiscCycleTabs = "TRUE";
      MiscTabCloseButtons = "TRUE";
      MiscTabCloseMiddleClick = "TRUE";
      MiscTabPosition = "GTK_POS_TOP";
      MiscHighlightUrls = "TRUE";
      MiscMiddleClickOpensUri = "FALSE";
      MiscCopyOnSelect = "FALSE";
      MiscShowRelaunchDialog = "TRUE";
      MiscRewrapOnResize = "TRUE";
      MiscUseShiftArrowsToScroll = "FALSE";
      MiscSlimTabs = "FALSE";
      MiscNewTabAdjacent = "FALSE";
      MiscSearchDialogOpacity = "100";
      MiscShowUnsafePasteDialog = "FALSE";
      MiscRightClickAction = "TERMINAL_RIGHT_CLICK_ACTION_CONTEXT_MENU";
      ColorForeground = "#dcdcdc";
      ColorBackground = "#2c2c2c";
      ColorCursor = "#dcdcdc";
      ColorPalette = "#3f3f3f;#705050;#60b48a;#dfaf8f;#9ab8d7;#dc8cc3;#8cd0d3;#dcdcdc;#709080;#dca3a3;#72d5a3;#f0dfaf;#94bff3;#ec93d3;#93e0e3;#ffffff";
    };
  };
}
