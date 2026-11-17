/// Profile rules shared by the service and the UI, so both validate the same
/// way and neither imports the other's layer.
abstract final class ProfileRules {
  static const minPasswordLength = 8;
  static const maxNameLength = 64;
}
