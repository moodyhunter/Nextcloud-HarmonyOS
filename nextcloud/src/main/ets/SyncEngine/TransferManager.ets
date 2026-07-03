import { BasicDataSource } from '../Utils/BasicDatasource';
import { Logger } from '../Utils/Logger';
import { BaseJob } from './Jobs/BaseJob';
import { DownloadJobData, DownloadTransferJob } from './Jobs/DownloadTransferJob';
import { TransferJob } from './Jobs/TransferJob';
import { UploadJobData, UploadTransferJob } from './Jobs/UploadTransferJob';

const TAG = 'SyncEngine/TransferManager';

export class JobManagerImpl {
    private tasks_: BasicDataSource<BaseJob>;
    private idSeq_ = 0;

    constructor() {
        Logger.Info(TAG, `created TransferManager`);
        this.tasks_ = new BasicDataSource<TransferJob>();
    }

    public get tasks() {
        return this.tasks_;
    }

    public addDownloadJob(jobData: DownloadJobData): DownloadTransferJob {
        let id = this.getNextId();
        let job = new DownloadTransferJob(id, jobData);
        this.tasks_.prependItem(job);
        return job;
    }

    public createUploadJob(jobData: UploadJobData): UploadTransferJob {
        const id = this.getNextId();
        const job = new UploadTransferJob(id, jobData);
        this.tasks_.prependItem(job);
        return job;
    }

    private getNextId(): number {
        return this.idSeq_++;
    }
}

export let JobManager = new JobManagerImpl();
