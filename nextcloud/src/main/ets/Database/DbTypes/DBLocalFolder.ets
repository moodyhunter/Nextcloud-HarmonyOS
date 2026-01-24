import { relationalStore } from '@kit.ArkData';
import { Logger } from '../../Utils/Logger';
import { DBItem, DBTableDescriptor } from '../DBManager';

const TAG = 'Database/DBLocalFolder';

export enum LocalFolderType {
    Regular,
    PhotoAlbum,
}

export class DBLocalSyncFolder implements DBItem {
    static readonly DB_TABLE_NAME: string = 'LocalFolders';
    id: number;
    localPath: string;
    alias: string;
    folderType: LocalFolderType;

    constructor(id: number, localPath: string, alias: string, folderType: LocalFolderType) {
        Logger.Debug(TAG, `constructor: enter`,
            `id: ${id}`,
            `localPath: '${localPath}'`,
            `alias: '${alias}'`,
            `folderType: ${folderType}`);
        this.id = id;
        this.localPath = localPath;
        this.alias = alias;
        this.folderType = folderType;
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
        bucket['folder_type'] = this.folderType;
        return bucket;
    }

    public toString(): string {
        return `DBLocalSyncFolder{id=${this.id}, localPath=${this.localPath}, alias=${this.alias}}`;
    }
}

type DBLocalSyncFolderColumnNames = 'folder_id' | 'local_path' | 'alias' | 'folder_type';

export const DBLocalSyncFolderTable: DBTableDescriptor<DBLocalSyncFolderColumnNames, DBLocalSyncFolder> = {
    tableName: DBLocalSyncFolder.DB_TABLE_NAME,
    columns: {
        'folder_id': { type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        'local_path': { type: 'TEXT', attrs: 'NOT NULL' },
        'alias': { type: 'TEXT', attrs: 'NOT NULL' },
        'folder_type': { type: 'INTEGER', attrs: 'NOT NULL' },
    },

    createItemFromBucket(bucket: relationalStore.ValuesBucket): DBLocalSyncFolder {
        let id = bucket['folder_id'] as number;
        let localPath = bucket['local_path'] as string;
        let alias = bucket['alias'] as string;
        let folderType = bucket['folder_type'] as number;
        return new DBLocalSyncFolder(id, localPath, alias, folderType);
    }
};
