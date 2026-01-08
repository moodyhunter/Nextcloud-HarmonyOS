import { relationalStore } from '@kit.ArkData';
import { Logger } from '../../Utils/Logger';
import { ColumnDescriptors, DBObject, DBObjectCreator } from '../DBManager';

const TAG = 'Database/DBSyncFolder';

export class DBSyncFolder implements DBObject {
    static readonly DB_TABLE_NAME: string = 'Folders';
    id: number;
    systemPath: string;
    alias: string;
    accountId: number;

    constructor(id: number, systemPath: string, alias: string, account_id: number) {
        this.id = id;
        this.systemPath = systemPath;
        this.alias = alias;
        this.accountId = account_id;
    }

    public getTableName(): string {
        return DBSyncFolder.DB_TABLE_NAME;
    }

    public toBucket(): relationalStore.ValuesBucket {
        let bucket: relationalStore.ValuesBucket = {};
        bucket['folder_id'] = this.id;
        bucket['system_path'] = this.systemPath;
        bucket['alias'] = this.alias;
        bucket['account_id'] = this.accountId;
        return bucket;
    }
}

class DBSyncFolderFactoryImpl implements DBObjectCreator<DBSyncFolder> {
    static readonly DB_COLUMN_DESC: ColumnDescriptors = [
        { column: 'folder_id', type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        { column: 'system_path', type: 'TEXT', attrs: 'NOT NULL' },
        { column: 'alias', type: 'TEXT', attrs: 'NOT NULL' },
        { column: 'account_id', type: 'INTEGER', attrs: 'NOT NULL' },
    ];

    getTableName(): string {
        return DBSyncFolder.DB_TABLE_NAME;
    }

    createFromBucket(bucket: relationalStore.ValuesBucket): DBSyncFolder {
        Logger.Info(TAG, `createFromBucket: enter, row: ${JSON.stringify(bucket)}`);
        let id = bucket['folder_id'] as number;
        let systemPath = bucket['system_path'] as string;
        let alias = bucket['alias'] as string;
        let account_id = bucket['account_id'] as number;
        return new DBSyncFolder(id, systemPath, alias, account_id);
    }

    getColumnDesc(): ColumnDescriptors {
        return DBSyncFolderFactoryImpl.DB_COLUMN_DESC;
    }
}

export const DBSyncFolderFactory = new DBSyncFolderFactoryImpl();
