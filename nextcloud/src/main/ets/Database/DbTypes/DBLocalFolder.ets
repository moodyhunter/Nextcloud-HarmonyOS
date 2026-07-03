import { relationalStore } from '@kit.ArkData';
import { Logger } from '../../Utils/Logger';
import { DBItem, DBTableDescriptor } from '../DBManager';

const TAG = 'Database/DBLocalFolder';

export enum LocalFolderType {
    Regular,
    PhotoAlbum,
}

@ObservedV2
export class DBLocalFolderConfig {
    @Trace instantUploadEnabled: boolean = false;

    constructor(record: Record<string, string | boolean>) {
        this.instantUploadEnabled = record['instantUploadEnabled'] as boolean ?? false;
    }

    public toJson() {
        let object: Record<string, string | boolean> = {
            'instantUploadEnabled': this.instantUploadEnabled,
        };

        return JSON.stringify(object);
    }
}

@ObservedV2
export class DBLocalFolder implements DBItem {
    static readonly DB_TABLE_NAME: string = 'LocalFolders';
    @Trace public id: number;
    @Trace public localPath: string;
    @Trace public alias: string;
    @Trace public folderType: LocalFolderType;
    public config: DBLocalFolderConfig;

    constructor(id: number, localPath: string, alias: string, folderType: LocalFolderType, config: DBLocalFolderConfig) {
        Logger.Debug(TAG, `constructor: enter`,
            `id: ${id}`,
            `localPath: '${localPath}'`,
            `alias: '${alias}'`,
            `folderType: ${folderType}`);
        this.id = id;
        this.localPath = localPath;
        this.alias = alias;
        this.folderType = folderType;
        this.config = config;
    }

    getTableDescription(): DBTableDescriptor<string, DBItem> {
        return DBLocalFolderTable;
    }

    public getTableName(): string {
        return DBLocalFolder.DB_TABLE_NAME;
    }

    public toBucket(isCreate: boolean): relationalStore.ValuesBucket {
        let bucket: relationalStore.ValuesBucket = {};
        if (isCreate === false) {
            bucket['folder_id'] = this.id;
        }
        bucket['local_path'] = this.localPath;
        bucket['alias'] = this.alias;
        bucket['folder_type'] = this.folderType;
        bucket['config'] = this.config.toJson();
        return bucket;
    }

    public toString(): string {
        return `DBLocalSyncFolder{id=${this.id}, localPath=${this.localPath}, alias=${this.alias}}`;
    }
}

type DBLocalSyncFolderColumnNames = 'folder_id' | 'local_path' | 'alias' | 'folder_type' | 'config';

export const DBLocalFolderTable: DBTableDescriptor<DBLocalSyncFolderColumnNames, DBLocalFolder> = {
    tableName: DBLocalFolder.DB_TABLE_NAME,
    columns: {
        'folder_id': { type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        'local_path': { type: 'TEXT', attrs: 'NOT NULL' },
        'alias': { type: 'TEXT', attrs: 'NOT NULL' },
        'folder_type': { type: 'INTEGER', attrs: 'NOT NULL' },
        'config': { type: 'TEXT', attrs: 'NOT NULL' },
    },
    primaryKey: 'folder_id',
    createItemFromBucket(bucket: relationalStore.ValuesBucket): DBLocalFolder {
        let id = bucket['folder_id'] as number;
        let localPath = bucket['local_path'] as string;
        let alias = bucket['alias'] as string;
        let folderType = bucket['folder_type'] as number;
        let config = new DBLocalFolderConfig(JSON.parse(bucket['config'] as string | undefined ?? '{}'));
        return new DBLocalFolder(id, localPath, alias, folderType, config);
    }
};
