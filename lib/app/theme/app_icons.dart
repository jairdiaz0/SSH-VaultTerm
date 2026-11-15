import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Single source of truth for the app's icons.
///
/// The UI uses Lucide (MIT, bundled font, no network). Replacing the library
/// means editing only this file. Sizes come from [AppIconSize].
abstract final class AppIcons {
  static const add = LucideIcons.plus;
  static const back = LucideIcons.arrowLeft;
  static const forward = LucideIcons.arrowRight;
  static const up = LucideIcons.arrowUp;
  static const down = LucideIcons.arrowDown;

  static const close = LucideIcons.x;
  static const more = LucideIcons.moreHorizontal;
  static const refresh = LucideIcons.refreshCw;
  static const settings = LucideIcons.settings;
  static const lock = LucideIcons.lock;
  static const logout = LucideIcons.logOut;
  static const login = LucideIcons.logIn;

  static const menu = LucideIcons.menu;
  static const panelLeft = LucideIcons.panelLeft;
  static const grid = LucideIcons.layoutGrid;
  static const list = LucideIcons.list;
  static const search = LucideIcons.search;
  static const sort = LucideIcons.arrowUpDown;

  static const shield = LucideIcons.shield;
  static const shieldAlert = LucideIcons.shieldAlert;
  static const fingerprint = LucideIcons.fingerprint;
  static const warning = LucideIcons.triangleAlert;
  static const error = LucideIcons.circleAlert;
  static const info = LucideIcons.info;
  static const success = LucideIcons.circleCheck;

  static const terminal = LucideIcons.terminal;
  static const folder = LucideIcons.folder;
  static const folderOpen = LucideIcons.folderOpen;
  static const folderPlus = LucideIcons.folderPlus;
  static const folderOff = LucideIcons.folderX;
  static const file = LucideIcons.file;
  static const download = LucideIcons.download;
  static const upload = LucideIcons.upload;
  static const linkOff = LucideIcons.link2Off;
  static const star = LucideIcons.star;

  static const users = LucideIcons.users;
  static const userAdd = LucideIcons.userPlus;
  static const radioOn = LucideIcons.circleDot;
  static const radioOff = LucideIcons.circle;
  static const eye = LucideIcons.eye;
  static const eyeOff = LucideIcons.eyeOff;
  static const delete = LucideIcons.trash2;
  static const offline = LucideIcons.cloudOff;
}

/// Consistent icon sizes.
abstract final class AppIconSize {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const hero = 40.0;
}
