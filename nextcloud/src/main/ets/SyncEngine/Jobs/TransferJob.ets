import { RemoteFolder } from '../../Database/Types/RemoteFolder';
import { Logger } from '../../Utils/Logger';
import { CreateSession } from '../../webdav/TransferUtils';
import {
    publishTransferEvent,
    TransferManagerEventCode,
    TransferType,
} from '../TransferManagerEventIPC';
import { BaseJob, JobData } from './BaseJob';
import { rcp } from '@kit.RemoteCommunicationKit';
//
export interface TransferJobData extends JobData {
    fileName: string;

    /**
     * The remote folder involved in the transfer
     */
    remoteFolder: RemoteFolder;
}

@ObservedV2
export class TransferJob extends BaseJob {
    readonly id: number;
    public readonly type: TransferType;
    public readonly filename: string;
    @Trace public totalSize: number = 1;
    @Trace public transferredSize: number = 0;
    @Trace public remoteFolder: RemoteFolder;
    @Trace protected historicalBatchesTransferredSize: number = 0;
    private readonly sessionExtraHeaders: Map<string, string> = new Map<string, string>();

    constructor(id: number, type: TransferType, data: TransferJobData, extraHeaders?: Map<string, string>) {
        super(`TransferJob/${TransferType[type]}/${data.fileName}`);
        this.id = id;
        this.type = type;
        this.filename = data.fileName;
        this.remoteFolder = data.remoteFolder;
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
