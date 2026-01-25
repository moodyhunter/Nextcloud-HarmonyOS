import { CreatePath, IsRemotePathExists } from '../../webdav/TransferUtils';
import { TransferJob, TransferJobData } from './TransferJob';
import { fileIo } from '@kit.CoreFileKit';
import { Logger } from '../../Utils/Logger';
import { rcp } from '@kit.RemoteCommunicationKit';
import { TransferType } from '../TransferManagerEventIPC';
import { NCommon } from '../../Common';

export interface UploadCallback {
    jobCreated,
    aboutToUpload,
}

export interface UploadJobData extends TransferJobData {
    /**
     * Local item modified time in milliseconds since epoch
     */
    mTime: number;

    /**
     * Uri of the local item
     */
    uri: string;

    /**
     * The relative path of the file being transferred within the folder structure, which can be used to derive the full paths:
     * localPath = localFolder.path + relativePath
     * remotePath = remoteFolder.path + relativePath
     */
    relativePath: string;
}

@ObservedV2
export class UploadTransferJob extends TransferJob {
    private uploadStatusCode: number = 0;
    private readonly uri: string;
    private readonly file: fileIo.File;
    private readonly fileStat: fileIo.Stat;
    private readonly relativePath: string;

    constructor(id: number, data: UploadJobData) {
        let extraHeaders = new Map<string, string>();
        extraHeaders.set('X-OC-MTime', `${Math.round(data.mTime / 1000)}`);
        super(id, TransferType.Upload, data, extraHeaders);
        this.relativePath = data.relativePath;
        this.uri = data.uri;
        try {
            this.fileStat = fileIo.statSync(this.uri);
            this.file = fileIo.openSync(this.uri);
            this.totalSize = this.fileStat.size;
        } catch (error) {
            Logger.Error(this.TAG, `failed to create readonly file: ${JSON.stringify(error)}`);
            throw error as Error;
        }
    }

    public get statusCode(): number {
        return this.uploadStatusCode;
    }

    protected async onTransferWork(session: rcp.Session) {
        Logger.Info(this.TAG, `doWork enter`);
        const account = this.remoteFolder.account;
        const destPath = this.remoteFolder.getFullPath(this.relativePath);
        const destFile = destPath + '/' + this.filename;

        let shouldReplace = NCommon.Preference.replaceExistingFiles;
        if (!shouldReplace) {
            if (await IsRemotePathExists(session, account, destFile)) {
                Logger.Info(this.TAG, `file already exists: ${destFile}, not replacing as per settings`);
                session.close();
                this.uploadStatusCode = 204; // No Content, file already exists
                return;
            }
        }
        {
            let mkdirResult = await CreatePath(this.remoteFolder.account, destPath);
            if (mkdirResult !== 201 && mkdirResult !== 409 && mkdirResult !== 405) {
                Logger.Error(this.TAG, `failed to create path: ${destPath}`)
                this.uploadStatusCode = mkdirResult;
                return;
            }
        }

        const tempDirectory = NCommon.RandomString(16);
        const chunkedUploadRemoteDir = account.chunkedUploadBaseUrl() + tempDirectory + `/`;
        session.configuration!.headers!['Destination'] = account.remoteBaseDirUrl() + destFile;

        try {
            let resp = await session.fetch(new rcp.Request(chunkedUploadRemoteDir, "MKCOL", {}));
            Logger.Info(this.TAG, `Created chunked upload temp directory '${tempDirectory}' with response: ${resp.statusCode}`);
            if (resp.statusCode !== 201) {
                throw new Error(`Failed to create chunked upload temp directory, status code: ${resp.statusCode}`);
            }
        } catch (e) {
            Logger.Error(this.TAG, `failed to create chunked upload temp directory '${tempDirectory}': ${e}`);
            await session.delete(chunkedUploadRemoteDir);
            await fileIo.close(this.file.fd);
            throw e as Error;
        }

        let remainingSize = this.fileStat.size;
        session.configuration!.headers!['OC-Total-Length'] = `${this.fileStat.size}`;
        try {
            let fileCount = 0;
            for (let uploadedSize = 0; uploadedSize < this.fileStat.size; ) {
                let chunkSize = Math.min(remainingSize, DEFAULT_CHUNK_SIZE);
                let arrayBuffer = new ArrayBuffer(chunkSize);
                let readLen = await fileIo.read(this.file.fd, arrayBuffer, {
                    length: chunkSize,
                    offset: uploadedSize
                });

                let chunkPath = chunkedUploadRemoteDir + fileCount.toString().padStart(5, '0');
                Logger.Info(this.TAG, `Read ${readLen} bytes into ArrayBuffer for chunked upload to ${chunkPath}`);

                let resp = await session.put(chunkPath, arrayBuffer);
                Logger.Info(this.TAG, `Chunk upload response for ${chunkPath}: ${resp.statusCode}`);

                if (resp.statusCode !== 201 && resp.statusCode !== 204) {
                    throw new Error(`Chunk upload failed with status code: ${resp.statusCode}`);
                }

                uploadedSize += readLen;
                remainingSize -= readLen;
                fileCount++;
                this.historicalBatchesTransferredSize = uploadedSize;
            }
            // Finalize chunked upload
            let moveRequest = new rcp.Request(chunkedUploadRemoteDir + '.file', "MOVE", {});
            let resp = await session.fetch(moveRequest);
            Logger.Info(this.TAG, `Finalized chunked upload with response: ${resp.statusCode}`);
            if (resp.statusCode !== 201 && resp.statusCode !== 204) {
                throw new Error(`Finalizing chunked upload failed with status code: ${resp.statusCode}`);
            }
            this.uploadStatusCode = resp.statusCode;
        } catch (e) {
            await session.delete(chunkedUploadRemoteDir);
            Logger.Error(this.TAG, `chunked upload failed: ${e}`);
        } finally {
            await fileIo.close(this.file.fd);
        }
    }
}

const DEFAULT_CHUNK_SIZE = 50 * 1024 * 1024; // 50 MB
