/**
 * Adapter of DataShare relational DB
 */
import { relationalStore } from '@kit.ArkData';
import { Logger } from './Logger';

const TAG = 'Utils/StorageAdapter';


const SQL_CREATE_TABLE = `
CREATE TABLE IF NOT EXISTS Accounts (
    account_id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT NOT NULL,
    username TEXT NOT NULL,
    password TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS Folders (
    folder_id INTEGER PRIMARY KEY AUTOINCREMENT,
    system_path TEXT NOT NULL,
    alias TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS FolderSyncInfo (
    folder_path INTEGER PRIMARY KEY AUTOINCREMENT,
    etag TEXT NOT NULL
);
`;

export class StorageAdapterImpl {
    store: relationalStore.RdbStore | undefined = undefined;

    async initDataStore(context: Context, storageName: string) {
        Logger.Info(TAG, `initDataStore: enter, storageName: ${storageName}`);
        let storeConfig: relationalStore.StoreConfig = {
            name: storageName,
            securityLevel: relationalStore.SecurityLevel.S3,
        };

        if (this.store) {
            Logger.Error(TAG, `initDataStore: duplicated init`);
            return;
        }

        try {
            this.store = await relationalStore.getRdbStore(context, storeConfig);
        } catch (e) {
            Logger.Error(TAG, `initDataStore: Failed to get RdbStore: ${JSON.stringify(e)}`);
            return;
        }

        Logger.Info(TAG, 'initDataStore: completed');
    }

    async upgradeDatabase(): Promise<void> {
        Logger.Info(TAG, 'upgradeDatabase: enter');
        if (!this.store) {
            Logger.Error(TAG, `upgradeDatabase: store is undefined`);
            return;
        }

        let transaction: relationalStore.Transaction;
        try {
            transaction = await this.store.createTransaction();
        } catch (error) {
            Logger.Error(TAG, `upgradeDatabase: failed to create transaction: ${JSON.stringify(error)}`);
            return;
        }
        try {
            let storeVersion = await transaction.execute('PRAGMA user_version');

            if (storeVersion === 0) {
                await transaction.execute(SQL_CREATE_TABLE);
                await transaction.execute('PRAGMA user_version = 1');
                storeVersion = 1;
            }
        } catch (e) {
            Logger.Error(TAG, `upgradeDatabase: failed to execute sql: ${JSON.stringify(e)}`);
            await transaction.rollback();
            return;
        }

        try {
            await transaction.commit();
        } catch (error) {
            Logger.Error(TAG, `upgradeDatabase: failed to commit transaction: ${JSON.stringify(error)}`);
        }
        Logger.Info(TAG, 'upgradeDatabase: completed');
        this.store.commit();
        // 请确保获取到RdbStore实例，完成数据表创建后，再进行数据库的增、删、改、查等操作
    }
}
