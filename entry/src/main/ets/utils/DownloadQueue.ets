import { DirectoryEntry, ListFiles, Logger } from "nextcloud";

const DOWNLOAD_DEPTH_FIRST: boolean = true;
const TAG = 'Utils/DownloadQueue';

export class DownloadItem {
    relativePath: string;
    isDirectory: boolean;

    constructor(relativePath: string, isDirectory: boolean) {
        this.relativePath = relativePath;
        this.isDirectory = isDirectory;
    }

    public makeChildItem(filename: string, isDirectory: boolean): DownloadItem {
        let relativePath = this.relativePath.endsWith('/') ? this.relativePath : this.relativePath + '/';
        return new DownloadItem(relativePath + filename, isDirectory);
    }
}


export class DownloadQueue {
    queue: DownloadItem[] = [];

    private async shiftNext(): Promise<DownloadItem | undefined> {
        let next = this.queue.shift();
        if (!next) {
            Logger.Info(TAG, `download queue is empty`);
            return undefined;
        }

        if (next.isDirectory) {
            Logger.Debug(TAG, `downloading dir: ${next.relativePath}`);
            let items = await ListFiles(next.relativePath);
            let downloadItems = items.map((item: DirectoryEntry): DownloadItem => {
                Logger.Info(TAG, `${item.name}`);
                return next!.makeChildItem(item.name, item.isDirectory);
            });

            if (DOWNLOAD_DEPTH_FIRST) {
                this.queue.unshift(...downloadItems);
            } else {
                this.queue.push(...downloadItems);
            }
        } else {
            Logger.Debug(TAG, `downloading file: ${next.relativePath}`);
        }
        return next;
    }

    public hasPendingItem() {
        return this.queue.length > 0;
    }

    public async getNextDownloadFile(): Promise<DownloadItem | undefined> {
        do {
            let next = await this.shiftNext();
            if (next !== undefined) {
                return next;
            }
        } while (this.hasPendingItem());
        Logger.Info(TAG, `download queue empty`);
        return undefined;
    }

    public addRootDir() {
        let rootItem = new DownloadItem('/', true);
        this.queue.push(rootItem);
    }
}
