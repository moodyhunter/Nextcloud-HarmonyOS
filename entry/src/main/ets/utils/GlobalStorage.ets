export const INSTANT_UPLOAD_PATH = '/InstantUpload/';

@ObservedV2
class GlobalStorageImpl {
    @Trace public SandboxBasePath: string = "";
}

export const GlobalStorage = new GlobalStorageImpl();
