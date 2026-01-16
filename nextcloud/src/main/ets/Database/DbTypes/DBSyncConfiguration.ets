import { DBItem, DBTableDescriptor } from "../DBManager";
import { relationalStore } from "@kit.ArkData";
import { DBRemoteFolderTable } from "./DBRemoteFolder";
import { DBLocalSyncFolderTable } from "./DBLocalFolder";

export class DBSyncConfiguration implements DBItem {
    static readonly DB_TABLE_NAME: string = 'SyncConfigurations';
    id: number;
    localFolderId: number;
    remoteFolderId: number;

    constructor(id: number, localFolderId: number, remoteFolderId: number) {
        this.id = id;
        this.localFolderId = localFolderId;
        this.remoteFolderId = remoteFolderId;
    }

    public getTableName(): string {
        return DBSyncConfiguration.DB_TABLE_NAME;
    }

    public toBucket(isCreate: boolean): relationalStore.ValuesBucket {
        let bucket: relationalStore.ValuesBucket = {};
        if (isCreate === false) {
            bucket['id'] = this.id;
        }
        bucket['local_folder_id'] = this.localFolderId;
        bucket['remote_folder_id'] = this.remoteFolderId;
        return bucket;
    }

    public toString(): string {
        return `DBSyncConfiguration{id=${this.id}, localFolderId=${this.localFolderId}, remoteFolderId=${this.remoteFolderId}}`;
    }
}

type DBSyncConfigurationColumnNames = 'id' | 'local_folder_id' | 'remote_folder_id';

export const DBSyncConfigurationTable: DBTableDescriptor<DBSyncConfigurationColumnNames, DBSyncConfiguration> = {
    tableName: DBSyncConfiguration.DB_TABLE_NAME,
    columns: {
        'id': { type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        'local_folder_id': {
            type: 'INTEGER', attrs: 'NOT NULL',
            foreignKey: {
                target: DBLocalSyncFolderTable,
                targetColumn: DBLocalSyncFolderTable.columns.folder_id,
            }
        },
        'remote_folder_id': {
            type: 'INTEGER', attrs: 'NOT NULL', foreignKey: {
                target: DBRemoteFolderTable,
                targetColumn: DBRemoteFolderTable.columns.folder_id,
            }
        },
    },
    createItemFromBucket(bucket: relationalStore.ValuesBucket): DBSyncConfiguration {
        let id = bucket['id'] as number;
        let localFolderId = bucket['local_folder_id'] as number;
        let remoteFolderId = bucket['remote_folder_id'] as number;
        return new DBSyncConfiguration(id, localFolderId, remoteFolderId);
    },
};
