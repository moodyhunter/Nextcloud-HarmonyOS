import { Logger } from '../../Utils/Logger';
import { DBItem, DBTableDescriptor } from '../DBManager';
import { relationalStore } from '@kit.ArkData';

const TAG = 'Database/DBAccount';

export class DBAccount implements DBItem {
    static readonly DB_TABLE_NAME: string = 'Accounts';
    id: number;
    username: string;
    password: string;
    hostname: string;

    constructor(id: number, hostname: string, username: string, password: string) {
        Logger.Debug(TAG, `constructor: enter, id=${id}, hostname=${hostname}, username=${username}`);
        this.id = id;
        this.hostname = hostname;
        this.username = username;
        this.password = password;
    }

    public getTableName(): string {
        return DBAccount.DB_TABLE_NAME;
    }

    public toBucket(): relationalStore.ValuesBucket {
        let bucket: relationalStore.ValuesBucket = {};
        bucket['account_id'] = this.id;
        bucket['username'] = this.username;
        bucket['password'] = this.password;
        bucket['hostname'] = this.hostname;
        return bucket;
    }
}

type DBAccountColumnNames = 'account_id' | 'hostname' | 'username' | 'password';

export const DBAccountTableInfo: DBTableDescriptor<DBAccountColumnNames, DBAccount> = {
    tableName: DBAccount.DB_TABLE_NAME,
    columns: {
        'account_id': { type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
        'hostname': { type: 'TEXT', attrs: 'NOT NULL' },
        'username': { type: 'TEXT', attrs: 'NOT NULL' },
        'password': { type: 'TEXT', attrs: 'NOT NULL' },
    },
    createItemFromBucket(bucket: relationalStore.ValuesBucket): DBAccount {
        let id = bucket['account_id'] as number;
        let username = bucket['username'] as string;
        let password = bucket['password'] as string;
        let hostname = bucket['hostname'] as string;
        return new DBAccount(id, hostname, username, password);
    }
};
