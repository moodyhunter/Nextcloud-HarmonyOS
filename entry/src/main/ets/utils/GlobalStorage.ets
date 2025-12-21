import { photoAccessHelper } from '@kit.MediaLibraryKit';

export const INSTANT_UPLOAD_PATH = '/InstantUpload/';

export class GlobalStorage {
    public static SandboxBasePath: string = "";
    public static pHelper: photoAccessHelper.PhotoAccessHelper;
}
