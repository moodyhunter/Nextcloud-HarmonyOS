import { DBItem, DBTableDescriptor } from '../DBManager';
import { relationalStore } from '@kit.ArkData';
import { Logger } from '../../Utils/Logger';
import { DBAccountTableInfo } from './DBAccount';

const TAG = 'Database/DBRemoteFolder';

export class DBRemoteFolder implements DBItem {
    static readonly DB_TABLE_NAME: string = 'RemoteFolders';
    id: number;
    accountId: number;
    remotePath: string;
    alias: string;

    constructor(id: number, accountId: number, remotePath: string, alias: string) {
        Logger.Info(TAG, `constructor: enter, id=${id}, accountId=${accountId}, remotePath=${remotePath}, alias=${alias}`);
        this.id = id;
        this.accountId = accountId;
        this.remotePath = remotePath;
        this.alias = alias;
    }

    public getTableName(): string {
        return DBRemoteFolder.DB_TABLE_NAME;
    }

    public toBucket(): relationalStore.ValuesBucket {
        let bucket: relationalStore.ValuesBucket = {};
        bucket['folder_id'] = this.id;
        bucket['account_id'] = this.accountId;
        bucket['remote_path'] = this.remotePath;
        bucket['alias'] = this.alias;
        return bucket;
    }
}

type DBRemoteFolderColumnNames = 'folder_id' | 'remote_path' | 'alias' | 'account_id';

export const DBRemoteFolderTable: DBTableDescriptor<DBRemoteFolderColumnNames, DBRemoteFolder> = {
    tableName: DBRemoteFolder.DB_TABLE_NAME,
    columns: {
        'folder_id': { type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        'remote_path': { type: 'TEXT', attrs: 'NOT NULL' },
        'alias': { type: 'TEXT', attrs: 'NOT NULL' },
        'account_id': {
            type: 'INTEGER',
            attrs: 'NOT NULL',
            foreignKey: {
                target: DBAccountTableInfo,
                targetColumn: DBAccountTableInfo.columns.account_id,
            },
        },
    },
    createItemFromBucket(bucket: relationalStore.ValuesBucket): DBRemoteFolder {
        let id = bucket['folder_id'] as number;
        let remotePath = bucket['remote_path'] as string;
        let alias = bucket['alias'] as string;
        let account_id = bucket['account_id'] as number;
        return new DBRemoteFolder(id, account_id, remotePath, alias);
    }
};
