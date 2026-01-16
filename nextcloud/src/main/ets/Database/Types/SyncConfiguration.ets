import { DBSyncConfiguration } from '../DbTypes/DBSyncConfiguration';
import { LocalFolder } from './LocalFolder';
import { RemoteFolder } from './RemoteFolder';

export class SyncConfiguration {
    public localFolder: LocalFolder;
    public remoteFolder: RemoteFolder;
    public dbSyncConfiguration: DBSyncConfiguration;

    constructor(localFolder: LocalFolder, remoteFolder: RemoteFolder, dbSyncConfiguration: DBSyncConfiguration) {
        this.localFolder = localFolder;
        this.remoteFolder = remoteFolder;
        this.dbSyncConfiguration = dbSyncConfiguration;
    }

    public get id(): number {
        return this.dbSyncConfiguration.id;
    }
}
