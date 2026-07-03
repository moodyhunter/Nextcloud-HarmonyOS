import { TransferJob, TransferJobData } from './TransferJob';
import { Logger } from '../../Utils/Logger';
import { rcp } from '@kit.RemoteCommunicationKit';
import { TransferType } from '../TransferManagerEventIPC';
import { LocalFolder } from '../../Database/Types/LocalFolder';

export interface DownloadJobData extends TransferJobData {
    /**
     * The local folder involved in the transfer
     */
    localFolder: LocalFolder;

    /**
     * The relative path of the file being transferred within the folder structure, which can be used to derive the full paths:
     * localPath = localFolder.path + relativePath
     * remotePath = remoteFolder.path + relativePath
     */
    relativePath: string;
}

@ObservedV2
export class DownloadTransferJob extends TransferJob {
    @Trace public localFolder: LocalFolder;
    @Trace public relativePath: string;

    constructor(id: number, data: DownloadJobData) {
        super(id, TransferType.Download, data);
        this.localFolder = data.localFolder;
        this.relativePath = data.relativePath;
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
