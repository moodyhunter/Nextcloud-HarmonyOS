import { LocalFolder } from '../../Database/Types/LocalFolder';
import { RemoteFolder } from '../../Database/Types/RemoteFolder';
import { Logger } from '../../Utils/Logger';
import { CreateSession } from '../../webdav/TransferUtils';
import {
    publishTransferEvent, TransferManagerEventCode, TransferType
} from '../TransferManagerEventIPC';
import { BaseJob, JobData } from './BaseJob';
import { rcp } from '@kit.RemoteCommunicationKit';

export interface TransferJobData extends JobData {
    fileName: string;

    /**
     * The local folder involved in the transfer
     */
    localFolder: LocalFolder;

    /**
     * The remote folder involved in the transfer
     */
    remoteFolder: RemoteFolder;

    /**
     * The relative path of the file being transferred within the folder structure, which can be used to derive the full paths:
     * localPath = localFolder.path + relativePath
     * remotePath = remoteFolder.path + relativePath
     */
    relativePath: string;
}

@ObservedV2
export class TransferJob extends BaseJob {
    readonly id: number;
    @Trace public readonly type: TransferType;
    @Trace public readonly filename: string;
    @Trace public totalSize: number = 1;
    @Trace public transferredSize: number = 0;
    @Trace public localFolder: LocalFolder;
    @Trace public remoteFolder: RemoteFolder;
    @Trace public relativePath: string;
    @Trace protected historicalBatchesTransferredSize: number = 0;
    private readonly sessionExtraHeaders: Map<string, string> = new Map<string, string>();

    constructor(id: number, type: TransferType, data: TransferJobData, extraHeaders?: Map<string, string>) {
        super(`TransferJob/${TransferType[type]}/${data.fileName}`);
        this.id = id;
        this.type = type;
        this.filename = data.fileName;
        this.localFolder = data.localFolder;
        this.remoteFolder = data.remoteFolder;
        this.relativePath = data.relativePath;
        if (extraHeaders) {
            this.sessionExtraHeaders = extraHeaders;
        }
    }

    public get progressPercentText() {
        let progress = this.transferredSize / this.totalSize;
        return `${(progress * 100).toFixed(1)}%`;
    }

    protected async onWork() {
        Logger.Info(this.TAG, `doWork enter`);

        const eventsHandler: rcp.HttpEventsHandler = {
            onDownloadProgress: (totalBytes: number, transferredBytes: number) => {
                this.onDownloadProgress(transferredBytes, totalBytes);
            },
            onUploadProgress: (_totalBytes: number, transferredBytes: number) => {
                this.onUploadProgress(transferredBytes);
            }
        };

        let session = CreateSession(this.remoteFolder.account, this.sessionExtraHeaders, eventsHandler);
        if (this.type === TransferType.Upload) {
            // Upload job - total size is known beforehand, notify task created immediately
            this.notifyTaskCreated();
        }

        const timerId = setTimeout(() => {
            publishTransferEvent({
                code: TransferManagerEventCode.TASK_PROGRESS,
                taskId: this.id,
                transferredSize: this.transferredSize
            })
        }, 500);

        try {
            await this.onTransferWork(session);
            session.close();
        } catch (error) {
            Logger.Error(this.TAG, `onTransferWork failed, error: ${JSON.stringify(error)}`);
            session.close();
            throw error as Error;
        } finally {
            clearTimeout(timerId);
        }

        this.transferredSize = this.totalSize;
        publishTransferEvent({
            code: TransferManagerEventCode.TASK_COMPLETED,
            taskId: this.id,
        })
    }

    protected async onTransferWork(_session: rcp.Session) {
        throw Error("onTransferWork not implemented");
    }

    protected onDownloadProgress(transferredBytes: number, totalBytes: number) {
        this.transferredSize = transferredBytes;
        if (this.totalSize === 0 && totalBytes > 0) {
            this.totalSize = totalBytes;
            // First time we get total size, notify task created
            this.notifyTaskCreated();
        } else {
            publishTransferEvent({
                code: TransferManagerEventCode.TASK_PROGRESS,
                taskId: this.id,
                transferredSize: this.transferredSize
            })
        }
    }

    protected onUploadProgress(transferredBytes: number) {
        Logger.Info(this.TAG, `onUploadProgress: transferredBytes=${transferredBytes}`);
        this.transferredSize = this.historicalBatchesTransferredSize + transferredBytes;
    }

    private notifyTaskCreated() {
        publishTransferEvent({
            code: TransferManagerEventCode.TASK_CREATED,
            taskId: this.id,
            task: {
                id: this.id,
                type: this.type,
                fileName: this.filename,
                totalSize: this.totalSize,
                transferredSize: this.transferredSize
            },
        });
    }
}
