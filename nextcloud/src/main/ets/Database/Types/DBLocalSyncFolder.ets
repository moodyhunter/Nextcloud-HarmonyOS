import { relationalStore } from '@kit.ArkData';
import { Logger } from '../../Utils/Logger';
import { DBItem, DBTableDescriptor } from '../DBManager';
import { DBAccountTableInfo } from './DBAccount';
import { DBRemoteFolderTable } from './DBRemoteFolder';

const TAG = 'Database/DBSyncFolder';

export class DBLocalSyncFolder implements DBItem {
    static readonly DB_TABLE_NAME: string = 'LocalSyncFolders';
    id: number;
    localPath: string;
    alias: string;
    accountId: number;
    remoteFolderId: number;

    constructor(id: number, localPath: string, alias: string, account_id: number, remote_folder_id: number) {
        Logger.Info(TAG, `constructor: enter, id=${id}, localPath=${localPath}, alias=${alias}, account_id=${account_id}, remote_folder_id=${remote_folder_id}`);
        this.id = id;
        this.localPath = localPath;
        this.alias = alias;
        this.accountId = account_id;
        this.remoteFolderId = remote_folder_id;
    }

    public getTableName(): string {
        return DBLocalSyncFolder.DB_TABLE_NAME;
    }

    public toBucket(): relationalStore.ValuesBucket {
        let bucket: relationalStore.ValuesBucket = {};
        bucket['folder_id'] = this.id;
        bucket['local_path'] = this.localPath;
        bucket['alias'] = this.alias;
        bucket['account_id'] = this.accountId;
        bucket['remote_folder_id'] = this.remoteFolderId;
        return bucket;
    }
}

type DBLocalSyncFolderColumnNames = 'folder_id' | 'local_path' | 'alias' | 'account_id' | 'remote_folder_id';

export const DBLocalSyncFolderTableInfo: DBTableDescriptor<DBLocalSyncFolderColumnNames, DBLocalSyncFolder> = {
    tableName: DBLocalSyncFolder.DB_TABLE_NAME,
    columns: {
        'folder_id': { type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        'account_id': {
            type: 'INTEGER',
            attrs: 'NOT NULL',
            foreignKey: {
                target: DBAccountTableInfo,
                targetColumn: DBAccountTableInfo.columns.account_id,
            },
        },
        'local_path': { type: 'TEXT', attrs: 'NOT NULL' },
        'alias': { type: 'TEXT', attrs: 'NOT NULL' },
        'remote_folder_id': {
            type: 'INTEGER',
            attrs: 'NOT NULL',
            foreignKey: {
                target: DBRemoteFolderTable,
                targetColumn: DBRemoteFolderTable.columns.folder_id,
            },
        },
    },

    createItemFromBucket(bucket: relationalStore.ValuesBucket): DBLocalSyncFolder {
        let id = bucket['folder_id'] as number;
        let localPath = bucket['local_path'] as string;
        let alias = bucket['alias'] as string;
        let account_id = bucket['account_id'] as number;
        let remote_folder_id = bucket['remote_folder_id'] as number;
        return new DBLocalSyncFolder(id, localPath, alias, account_id, remote_folder_id);
    }
};
