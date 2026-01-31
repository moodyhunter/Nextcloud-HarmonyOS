import { photoAccessHelper as PHelper } from '@kit.MediaLibraryKit';
import { JobManager } from '../Index';
import { image } from '@kit.ImageKit';
import { FormatTime } from '../Utils/CommonUtils';
import { RemoteFolder } from '../Database/Types/RemoteFolder';
import { BaseJob, JobState } from './Jobs/BaseJob';
import { UploadJobData, UploadTransferJob } from './Jobs/UploadTransferJob';
import { Logger } from '../Utils/Logger';

const TAG = 'PhotoItem';
const DEFAULT_FORMAT = 'yyyy/MM/';

export enum UploadStatus {
    None, // not yet started
    Pending, // scheduled, not yet transmitted
    Uploading, // transmitting
    Existed, // existed
    Completed, // upload completed
    Failed, // upload failed
    FailedCreatingPath, // failed to create one or more parent path
}

@ObservedV2
export class PhotoItem {
    @Trace uploadStatus: UploadStatus = UploadStatus.None;
    private innerAsset: PHelper.PhotoAsset;
    private uploadJob: Optional<UploadTransferJob> = undefined;

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

    get ownerAlbumId(): number {
        return Number(this.innerAsset.get('owner_album_id'));
    }

    async getThumbnail(size?: image.Size): Promise<image.PixelMap> {
        return await this.innerAsset.getThumbnail(size);
    }

    public getUploadJobData(categoryName: string, remoteFolder: RemoteFolder): UploadJobData {
        return {
            fileName: this.displayName,
            mTime: this.dateTakenMs,
            uri: this.uri,
            remoteFolder: remoteFolder,
            relativePath: categoryName + '/' + FormatTime(this.dateTaken, DEFAULT_FORMAT) + '/',
        };
    }

    public getUploadJob(categoryName: string, remoteFolder: RemoteFolder): UploadTransferJob {
        Logger.Info(TAG, `getUploadJob: enter`);
        if (this.uploadJob) {
            return this.uploadJob;
        }

        this.uploadJob = JobManager.createUploadJob(this.getUploadJobData(categoryName, remoteFolder));

        this.uploadJob.addStateListener((baseJob: BaseJob, state: JobState) => {
            switch (state) {
                case JobState.PENDING:
                    this.uploadStatus = UploadStatus.Pending;
                    break;
                case JobState.IN_PROGRESS:
                    this.uploadStatus = UploadStatus.Uploading;
                    break;
                case JobState.COMPLETED:
                case JobState.FAILED: {
                    let uploadJob = baseJob as UploadTransferJob;
                    if (uploadJob.statusCode === 201) {
                        this.uploadStatus = UploadStatus.Completed;
                    } else if (uploadJob.statusCode === 204) {
                        this.uploadStatus = UploadStatus.Existed;
                    } else {
                        this.uploadStatus = UploadStatus.Failed;
                    }
                }
            }
        });
        return this.uploadJob;
    }
}
