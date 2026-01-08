import { BasicDataSource } from './Utils/BasicDatasource';

export enum TransferType {
    DOWNLOAD,
    UPLOAD,
}

@Observed
export class TransferTask {
    public readonly type: TransferType;
    public readonly filename: string;

    public totalSize: number = 1;
    public transferedSize: number = 0;

    public updateProgress(transferSize: number, totalSize: number) {
        if (this.totalSize != totalSize) {
            this.totalSize = totalSize;
        }
        this.transferedSize = transferSize;
        return this.transferedSize / this.totalSize;
    }

    public get progressPercentText() {
        let progress = this.transferedSize / this.totalSize;
        return `${(progress * 100).toFixed(1)}%`;
    }

    constructor(type: TransferType, filename: string) {
        this.type = type;
        this.filename = filename;
    }
}

@Observed
export class TransferManagerImpl {
    private tasks_: BasicDataSource<TransferTask>;

    public get tasks() {
        return this.tasks_;
    }

    constructor() {
        this.tasks_ = new BasicDataSource<TransferTask>();
    }

    public addTransferTask(type: TransferType, fileName: string): TransferTask {
        let task = new TransferTask(type, fileName);
        return this.tasks_.prependItem(task);
    }
}


export let TransferManager = new TransferManagerImpl();
