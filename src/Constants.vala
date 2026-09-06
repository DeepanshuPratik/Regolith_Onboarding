namespace linux_onboarding {
    // This is a compile-time constant.
    //
    // Also the window's Wayland app_id (set from main.vala) and the basename of
    // the installed desktop file. meson.build asserts that this string and
    // data/<APP_ID>.desktop agree; change one and you must change all three.
    public const string APP_ID = "org.linux.Onboarding";

    // This must also be a compile-time constant, so we write it out fully.
    public const string APP_PATH = "/org/linux/Onboarding";

    // One directory under $XDG_CONFIG_HOME (and the system config dirs) for
    // everything this app reads or writes: workflows/ and the state file. Here
    // rather than on WorkflowLocator because OnboardingState needs it too, and
    // reaching the locator for a string would drag workflow parsing into the
    // test target.
    public const string DATA_SUBDIR = "linux-onboarding";
}
