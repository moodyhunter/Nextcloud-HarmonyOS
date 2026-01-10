import { Logger } from '../../Utils/Logger';
import { DBItem, ColumnDescriptors, DBObjectCreator } from '../DBManager';
import { relationalStore } from '@kit.ArkData';

const TAG = 'Database/DBAccount';

export class DBAccount implements DBItem {
    static readonly DB_TABLE_NAME: string = 'Accounts';
    id: number;
    username: string;
    password: string;
    hostname: string;

    constructor(id: number, hostname: string, username: string, password: string) {
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

class DBAccountFactoryImpl implements DBObjectCreator<DBAccount> {
    getTableName(): string {
        return DBAccount.DB_TABLE_NAME;
    }

    createFromBucket(bucket: relationalStore.ValuesBucket): DBAccount {
        Logger.Info(TAG, `createFromBucket: enter, row: ${JSON.stringify(bucket)}`);
        let id = bucket['account_id'] as number;
        let username = bucket['username'] as string;
        let password = bucket['password'] as string;
        let hostname = bucket['hostname'] as string;
        return new DBAccount(id, hostname, username, password);
    }

    getColumnDesc(): ColumnDescriptors {
        const desc: ColumnDescriptors = [
            { column: 'account_id', type: 'INTEGER', attrs: 'PRIMARY KEY AUTOINCREMENT', },
            { column: 'hostname', type: 'TEXT', attrs: 'NOT NULL' },
            { column: 'username', type: 'TEXT', attrs: 'NOT NULL' },
            { column: 'password', type: 'TEXT', attrs: 'NOT NULL' },
        ];
        return desc;
    }
}

export const DBAccountFactory = new DBAccountFactoryImpl();
