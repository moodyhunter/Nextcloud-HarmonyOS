import { TransferJob, TransferJobData } from './TransferJob';
import { Logger } from '../../Utils/Logger';
import { rcp } from '@kit.RemoteCommunicationKit';
import { TransferType } from '../TransferManagerEventIPC';

export interface DownloadJobData extends TransferJobData {}

@ObservedV2
export class DownloadTransferJob extends TransferJob {
    constructor(id: number, data: DownloadJobData) {
        super(id, TransferType.Download, data);
    }

    protected async onTransferWork(session: rcp.Session) {
        Logger.Info(this.TAG, `onTransferWork enter`);
        const localFullPath = this.localFolder.getFullPath(this.relativePath);
        const remoteFullPath = this.remoteFolder.getFullPath(this.relativePath);

        let downloadToFileOptions: rcp.DownloadToFile = {
            kind: "file",
            file: localFullPath,
        };


        await session.downloadToFile(this.remoteFolder.account.remoteBaseDirUrl() + remoteFullPath, downloadToFileOptions);

    }
}
