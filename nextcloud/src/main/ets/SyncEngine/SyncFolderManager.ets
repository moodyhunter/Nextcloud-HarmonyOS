// Manage mappings between Account -=> SyncFolder
import { Logger } from '../Utils/Logger';
import { DBManager } from '../Database/DBManager';
import { DBSyncConfiguration, DBSyncConfigurationTable } from '../Database/DbTypes/DBSyncConfiguration';
import { LocalFolder } from '../Database/Types/LocalFolder';
import { RemoteFolder } from '../Database/Types/RemoteFolder';
import { DBLocalSyncFolder, DBLocalSyncFolderTable, LocalFolderType } from '../Database/DbTypes/DBLocalFolder';
import { DBRemoteFolder, DBRemoteFolderTable } from '../Database/DbTypes/DBRemoteFolder';
import { Account } from '../Account/Account';
import { SyncConfiguration } from '../Database/Types/SyncConfiguration';

const TAG = 'SyncEngine/SyncFolderManager';

@ObservedV2
export class SyncFolderManager {
    @Trace private configurations_: Map<number, SyncConfiguration> = new Map();
    @Trace private localFolders_: Map<number, LocalFolder> = new Map();
    @Trace private remoteFolders_: Map<number, RemoteFolder> = new Map();
    private dbManager_: DBManager;

    constructor(dbManager: DBManager) {
        Logger.Info(TAG, `constructor`);
        this.dbManager_ = dbManager;
    }

    public get allLocalFolders(): Map<number, LocalFolder> {
        return this.localFolders_;
    }

    public get allSyncConfigurations(): Map<number, SyncConfiguration> {
        return this.configurations_;
    }

    public async startWatchForChanges(): Promise<void> {
        Logger.Info(TAG, `startWatchForChanges: enter`);
    }

    public async addLocalAlbumFolder(albumId: number, alias: string): Promise<LocalFolder> {
        Logger.Info(TAG, `addLocalFolder: enter`);
        let dbLocalFolder = new DBLocalSyncFolder(0, albumId.toString(), alias, LocalFolderType.PhotoAlbum);
        let localFolder = new LocalFolder(dbLocalFolder);
        let insertedId = await this.dbManager_.createItem(dbLocalFolder);
        dbLocalFolder.id = insertedId!;
        this.localFolders_.set(dbLocalFolder.id, localFolder);
        Logger.Info(TAG, `addLocalFolder: added local folder id ${dbLocalFolder.id} with albumId ${albumId}`);
        return localFolder;
    }

    public async addLocalFolder(localPath: string, alias: string): Promise<LocalFolder> {
        Logger.Info(TAG, `addLocalFolder: enter`);
        let dbLocalFolder = new DBLocalSyncFolder(0, localPath, alias, LocalFolderType.Regular);
        let localFolder = new LocalFolder(dbLocalFolder);
        let insertedId = await this.dbManager_.createItem(dbLocalFolder);
        dbLocalFolder.id = insertedId!;
        this.localFolders_.set(dbLocalFolder.id, localFolder);
        Logger.Info(TAG, `addLocalFolder: added local folder id ${dbLocalFolder.id} with path ${localPath}`);
        return localFolder;
    };

    public async addRemoteFolder(account: Account, remotePath: string, alias: string): Promise<RemoteFolder> {
        Logger.Info(TAG, `addRemoteFolder: enter`);
        let dbRemoteFolder = new DBRemoteFolder(0, account.id, remotePath, alias);
        let remoteFolder = new RemoteFolder(dbRemoteFolder);
        let insertedId = await this.dbManager_.createItem(dbRemoteFolder);
        dbRemoteFolder.id = insertedId!;
        this.remoteFolders_.set(dbRemoteFolder.id, remoteFolder);
        Logger.Info(TAG, `addRemoteFolder: added remote folder id ${dbRemoteFolder.id} with path ${remotePath}`);
        return remoteFolder;
    }

    public async addSyncConfiguration(
        localFolder: LocalFolder,
        remoteFolder: RemoteFolder
    ): Promise<SyncConfiguration> {
        Logger.Info(TAG, `addSyncConfiguration: enter`);
        let dbSyncConfiguration = new DBSyncConfiguration(0, localFolder.id, remoteFolder.id);
        let insertedId = await this.dbManager_.createItem(dbSyncConfiguration);
        dbSyncConfiguration.id = insertedId!;
        const syncConfig = new SyncConfiguration(localFolder, remoteFolder, dbSyncConfiguration);
        this.configurations_.set(dbSyncConfiguration.id, syncConfig);
        Logger.Info(TAG, `${JSON.stringify(this.configurations_.get(dbSyncConfiguration.id))}`);
        Logger.Info(
            TAG,
            `addSyncConfiguration: added configuration id ${insertedId} with local folder id ${localFolder.id} and remote folder id ${remoteFolder.id}`
        );
        return syncConfig;
    }

    public async removeSyncConfiguration(syncConfiguration: SyncConfiguration): Promise<void> {
        Logger.Info(TAG, `removeSyncConfiguration: enter for configuration id ${syncConfiguration.id}`);
        await this.dbManager_.deleteItemById(syncConfiguration.id, syncConfiguration.dbSyncConfiguration);
        this.configurations_.delete(syncConfiguration.id);
        Logger.Info(TAG, `removeSyncConfiguration: removed configuration id ${syncConfiguration.id}`);
    }

    public async loadSyncFolders(): Promise<void> {
        Logger.Info(TAG, `loadSyncFolders: enter`);
        let localFolders = await this.dbManager_.getItems(DBLocalSyncFolderTable);
        for (let localFolder of localFolders) {
            this.localFolders_.set(localFolder.id, new LocalFolder(localFolder));
        }

        let remoteFolders = await this.dbManager_.getItems(DBRemoteFolderTable);
        for (let remoteFolder of remoteFolders) {
            this.remoteFolders_.set(remoteFolder.id, new RemoteFolder(remoteFolder));
        }

        let dbSyncConfiguration = await this.dbManager_.getItems(DBSyncConfigurationTable);
        for (let conf of dbSyncConfiguration) {
            const localFolder = await this.getLocalFolderById(conf.localFolderId);
            const remoteFolder = await this.getRemoteFolderById(conf.remoteFolderId);
            if (!localFolder || !remoteFolder) {
                Logger.Error(
                    TAG,
                    `loadSyncFolders: failed to load sync configuration id ${conf.id} due to missing local or remote folder`
                );
                continue;
            }

            const syncConfig = new SyncConfiguration(localFolder, remoteFolder, conf);
            this.configurations_.set(conf.id, syncConfig);
            Logger.Info(
                TAG,
                `loadSyncFolders: loaded sync configuration id ${conf.id} with local folder id ${localFolder.id} and remote folder id ${remoteFolder.id}`
            );
        }
        Logger.Info(TAG, `loadSyncFolders: loaded total ${this.configurations_.size} sync configurations`);
    }

    private async getLocalFolderById(id: number): Promise<LocalFolder | null> {
        let existing = this.localFolders_.get(id);
        if (existing) {
            return existing;
        }

        let dbLocalFolder =
            await this.dbManager_.getItemById(id, DBLocalSyncFolderTable.columns.folder_id, DBLocalSyncFolderTable);
        if (!dbLocalFolder) {
            Logger.Error(TAG, `getLocalFolderById: local folder id ${id} not found`);
            return null;
        }

        Logger.Info(TAG, `getLocalFolderById: ${dbLocalFolder.id}`);
        existing = new LocalFolder(dbLocalFolder);
        this.localFolders_.set(id, existing);
        return existing;
    }

    private async getRemoteFolderById(id: number): Promise<RemoteFolder | null> {
        let existing = this.remoteFolders_.get(id);
        if (existing) {
            return existing;
        }

        let dbRemoteFolder =
            await this.dbManager_.getItemById(
                id,
                DBRemoteFolderTable.columns.folder_id,
                DBRemoteFolderTable
            );
        if (!dbRemoteFolder) {
            Logger.Error(TAG, `getRemoteFolderById: remote folder id ${id} not found`);
            return null;
        }
        existing = new RemoteFolder(dbRemoteFolder);
        this.remoteFolders_.set(id, existing);
        return existing;
    }
}
