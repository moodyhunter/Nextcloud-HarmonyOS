import { photoAccessHelper as PHelper } from '@kit.MediaLibraryKit';
import { CreatePath, Logger, UploadFile } from 'nextcloud';
import { promptAction } from '@kit.ArkUI';
import { TimeToPath } from '../utils/Utils';
import { image } from '@kit.ImageKit';

const TAG = 'PhotoItem';

export enum UploadStatus {
    None,
    Uploading,
    Uploaded,
    Failed,
    Existed,
}

export enum UploadResult {
    FAILED,
    EXISTED,
    SUCCEEDED,
}

@Observed
export class PhotoItem {
    uploadStatus: UploadStatus = UploadStatus.None;
    private innerAsset: PHelper.PhotoAsset;

    constructor(asset: PHelper.PhotoAsset) {
        this.innerAsset = asset;
    }

    get displayName(): string {
        return this.innerAsset.displayName ?? '';
    }

    get uri(): string {
        return this.innerAsset.uri ?? '';
    }

    get dateTaken(): Date {
        return new Date(this.innerAsset.get(PHelper.PhotoKeys.DATE_TAKEN_MS) as number);
    }

    get dateTakenMs(): number {
        return this.innerAsset.get(PHelper.PhotoKeys.DATE_TAKEN_MS) as number;
    }

    get size(): number {
        return this.innerAsset.get(PHelper.PhotoKeys.SIZE) as number ?? 0;
    }

    get photoType(): PHelper.PhotoType {
        return this.innerAsset.get(PHelper.PhotoKeys.PHOTO_TYPE) as PHelper.PhotoType;
    }

    get coverPosition(): number {
        return this.innerAsset.get(PHelper.PhotoKeys.COVER_POSITION) as number;
    }

    get isVideo(): boolean {
        return this.photoType === PHelper.PhotoType.VIDEO;
    }

    async getThumbnail(size?: image.Size): Promise<image.PixelMap> {
        return await this.innerAsset.getThumbnail(size);
    }

    async upload(targetPath: string): Promise<UploadResult> {
        this.uploadStatus = UploadStatus.Uploading;
        let path = targetPath + TimeToPath(this.dateTaken);
        let mkdirResult = await CreatePath(path);
        if (mkdirResult !== 201 && mkdirResult !== 409 && mkdirResult !== 405) {
            // 405 is the status code for "already exists"
            Logger.Error(TAG, `Failed to create path: ${path}`);
            promptAction.showToast({
                message: `Failed to create path: ${path}: ${mkdirResult}`,
                duration: 2000,
            });
        }

        let ret: UploadResult = UploadResult.FAILED;

        let message = "";
        let fd = await this.innerAsset.getReadOnlyFd();
        let uploadResult = await UploadFile(this.displayName, this.dateTakenMs, path, fd);
        let uploadResult = await UploadFile(this.displayName, this.dateTakenMs, path, this.uri);
        if (uploadResult !== 201 && uploadResult !== 204) {
            message = `Failed: ${this.displayName}: ${uploadResult}`;
            this.uploadStatus = UploadStatus.Failed;
            ret = UploadResult.FAILED;
        } else if (uploadResult === 204) {
            message = `File Existed: ${this.displayName}`;
            this.uploadStatus = UploadStatus.Existed;
            ret = UploadResult.EXISTED;
        } else {
            message = `Uploaded: ${this.displayName}`;
            this.uploadStatus = UploadStatus.Uploaded;
            ret = UploadResult.SUCCEEDED;
        }

        Logger.Info(TAG, `upload result: "${message}"`);
        if (ret !== UploadResult.EXISTED) {
            promptAction.showToast({ message, duration: 2000 });
        }
        return ret;
    }
}
