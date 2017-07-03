# Xamarin.Android API Compatibility

Xamarin.Android assemblies need to provide and maintain backward compatibility;
we don't want to break developers and customers investment in our platform.

This is done by maintaining a set of "known good" API descriptions for the
assemblies that Xamarin.Android cares about, and then on every build comparing
the built assemblies against the tracked API descriptions to check for or
alert about API breakage.

The [`mono-api-info`][mono-api-info] utility is used to create the API
descriptions. The output of the `mono-api-info` utility is preserved
in the `reference` directory.

[mono-api-info]: http://www.mono-project.com/archived/generating_class_status_pages/

The `mono-api-html` utility is used to compare API descriptions and check for
API breakage between the descriptions.

# Usage

The [`make check` target](#check) will compare assemblies against the
reference API description.

The [`make update` target](#update) will update the API descriptions.

Both `make check` and `make update` accept the following optional **make**(1)
variables:

* `$(LAST_STABLE_FRAMEWORK)`: The directory name of the last stable
    TargetFrameworkVersion to use. For Xamarin.Android 7.3, this is `v7.1`.
    This value is probed from the `$(XA_FRAMEWORK_DIR)` contents.
* `$(MONO_API_HTML)`: The `mono-api-html` to use.
* `$(MONO_API_INFO)`: The `mono-api-info` to use.
* `$(REFERENCE_DIR)`: Where the `mono-api-info` reference API descriptions are
    stored. This value defaults to `reference`.
* `$(STABLE_FRAMEWORKS)`: The `$(TargetFrameworkVersion)`s which are considered
    "stable" and should be checked for API compatibility. This list of values
    consists of the directories present within `$(XA_FRAMEWORK_DIR)`.
* `$(XA_FRAMEWORK_DIR)`: The directory of the Xamarin.Android `MonoAndroid`
    framework directory.

    On macOS, this defaults to `/Library/Frameworks/Xamarin.Android.framework/Libraries/xbuild-frameworks/MonoAndroid`.


<a name="check" />

## `make check`

Use the `make check` target to compare a set of Xamarin.Android assemblies
against the reference API description. It accepts the following optional
**make**(1) variables:

For example, to check a local Xamarin.Android build against the reference APIs:

	make check XA_FRAMEWORK_DIR=/path/to/xamarin-android/bin/Debug/lib/xbuild-frameworks/MonoAndroid

<a name="update" />

## `make update`

Use the `make update` target to update the reference API description against
the set of Xamarin.Android assemblies located in `$(XA_FRAMEWORK_DIR)`:

	make update XA_FRAMEWORK_DIR=/path/to/xamarin-android/bin/Debug/lib/xbuild-frameworks/MonoAndroid


