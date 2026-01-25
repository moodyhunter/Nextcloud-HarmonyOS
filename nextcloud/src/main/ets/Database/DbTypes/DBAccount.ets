import { Logger } from '../../Utils/Logger';
import { DBItem, DBTableDescriptor } from '../DBManager';
import { relationalStore } from '@kit.ArkData';

const TAG = 'Database/DBAccount';

/**
 * Backwards compatible, do not change field names
 */
export interface AccountConfig {
    instantUploadFolderId: number
}

export class DBAccount implements DBItem {
    static readonly DB_TABLE_NAME: string = 'Accounts';
    id: number;
    username: string;
    password: string;
    hostname: string;
    config: AccountConfig;

    constructor(id: number, hostname: string, username: string, password: string, config: AccountConfig) {
        Logger.Debug(TAG, `constructor: enter, id=${id}, hostname=${hostname}, username=${username}`);
        this.id = id;
        this.hostname = hostname;
        this.username = username;
        this.password = password;
        this.config = config;
    }

    getTableDescription(): DBTableDescriptor<string, DBItem> {
        return DBAccountTableInfo;
    }

    public getTableName(): string {
        return DBAccount.DB_TABLE_NAME;
    }

    public toBucket(isCreate: boolean): relationalStore.ValuesBucket {
        let bucket: relationalStore.ValuesBucket = {};
        if (isCreate === false) {
            bucket['account_id'] = this.id;
        }
        bucket['username'] = this.username;
        bucket['password'] = this.password;
        bucket['hostname'] = this.hostname;
        bucket['config'] = JSON.stringify(this.config);
        return bucket;
    }
}

type DBAccountColumnNames = 'account_id' | 'hostname' | 'username' | 'password' | 'config';

export const DBAccountTableInfo: DBTableDescriptor<DBAccountColumnNames, DBAccount> = {
    tableName: DBAccount.DB_TABLE_NAME,
    columns: {
        'account_id': { type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        'hostname': { type: 'TEXT', attrs: 'NOT NULL' },
        'username': { type: 'TEXT', attrs: 'NOT NULL' },
        'password': { type: 'TEXT', attrs: 'NOT NULL' },
        'config': { type: 'TEXT', }
    },
    primaryKey: 'account_id',
    createItemFromBucket(bucket: relationalStore.ValuesBucket): DBAccount {
        let id = bucket['account_id'] as number;
        let username = bucket['username'] as string;
        let password = bucket['password'] as string;
        let hostname = bucket['hostname'] as string;
        let config: AccountConfig = JSON.parse(bucket['config'] as string);
        return new DBAccount(id, hostname, username, password, config);
    }
};
