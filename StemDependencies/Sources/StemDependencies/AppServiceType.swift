import StemRuntimeSDK

/// Custom service type for external services not built into StemRuntimeSDK.
///
/// Host apps register concrete service implementations against these cases —
/// e.g. `renderer.register(LocationService.self, as: AppServiceType.location)` —
/// which makes the service available to StemJSON modules that declare it as
/// a dependency and invoke it via a `service` action.
public enum AppServiceType: String, StemDependencyType {
    case location
}
