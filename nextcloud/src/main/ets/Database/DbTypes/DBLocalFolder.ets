import { relationalStore } from '@kit.ArkData';
import { Logger } from '../../Utils/Logger';
import { DBItem, DBTableDescriptor } from '../DBManager';

const TAG = 'Database/DBSyncFolder';

export class DBLocalSyncFolder implements DBItem {
    static readonly DB_TABLE_NAME: string = 'LocalFolders';
    id: number;
    localPath: string;
    alias: string;

    constructor(id: number, localPath: string, alias: string) {
        Logger.Info(TAG, `constructor: enter, id=${id}, localPath=${localPath}, alias=${alias}`);
        this.id = id;
        this.localPath = localPath;
        this.alias = alias;
    }

    public getTableName(): string {
        return DBLocalSyncFolder.DB_TABLE_NAME;
    }

    public toBucket(isCreate: boolean): relationalStore.ValuesBucket {
        let bucket: relationalStore.ValuesBucket = {};
        if (isCreate === false) {
            bucket['folder_id'] = this.id;
        }
        bucket['local_path'] = this.localPath;
        bucket['alias'] = this.alias;
        return bucket;
    }

    public toString(): string {
        return `DBLocalSyncFolder{id=${this.id}, localPath=${this.localPath}, alias=${this.alias}}`;
    }
}

type DBLocalSyncFolderColumnNames = 'folder_id' | 'local_path' | 'alias';

export const DBLocalSyncFolderTable: DBTableDescriptor<DBLocalSyncFolderColumnNames, DBLocalSyncFolder> = {
    tableName: DBLocalSyncFolder.DB_TABLE_NAME,
    columns: {
        'folder_id': { type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        'local_path': { type: 'TEXT', attrs: 'NOT NULL' },
        'alias': { type: 'TEXT', attrs: 'NOT NULL' },
    },

    createItemFromBucket(bucket: relationalStore.ValuesBucket): DBLocalSyncFolder {
        let id = bucket['folder_id'] as number;
        let localPath = bucket['local_path'] as string;
        let alias = bucket['alias'] as string;
        return new DBLocalSyncFolder(id, localPath, alias);
    }
};
