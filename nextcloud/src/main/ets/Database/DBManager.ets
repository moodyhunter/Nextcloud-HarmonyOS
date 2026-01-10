import { relationalStore } from '@kit.ArkData';
import { Logger } from '../Utils/Logger';
import { DBAccountFactory } from './Types/DBAccount';
import { DBSyncFolderFactory } from './Types/DBSyncFolder';

const TAG = 'Database/DBManager';

export interface ColumnDescriptor {
    column: string; ///< Column name
    type: string; ///< Data type (e.g., INTEGER, TEXT)
    attrs?: string; ///< Additional attributes (e.g., PRIMARY KEY, NOT NULL)
}

export type ColumnDescriptors = ColumnDescriptor[];

interface DBGetTableName {
    getTableName(): string;
}

interface DBTableDescriptor extends DBGetTableName {
    getColumnDesc(): ColumnDescriptors;
}

/**
 * Interface for database items that can be converted to a ValuesBucket.
 */
export interface DBItem extends DBGetTableName {
    toBucket(): relationalStore.ValuesBucket;
}

/**
 * Interface for creating database objects from a ValuesBucket.
 */
export interface DBObjectCreator<T extends DBItem> extends DBTableDescriptor {
    createFromBucket(bucket: relationalStore.ValuesBucket): T;
}

export class DBManager {
    store: relationalStore.RdbStore | undefined = undefined;

    static generateTableCreationScript(descriptor: DBTableDescriptor): string {
        let columnsDef: string[] = [];
        for (let col of descriptor.getColumnDesc()) {
            let colDef = `${col.column} ${col.type}`;
            if (col.attrs) {
                colDef += ` ${col.attrs}`;
            }
            columnsDef.push(colDef);
        }
        return `CREATE TABLE IF NOT EXISTS ${descriptor.getTableName()} (${columnsDef.join(', ')});`;
    }

    static gatherTableCreationScripts(): string[] {
        let result: string[] = [];
        result.push(DBManager.generateTableCreationScript(DBAccountFactory));
        result.push(DBManager.generateTableCreationScript(DBSyncFolderFactory));
        return result;
    }

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
                const creationScripts = DBManager.gatherTableCreationScripts();
                for (let sql of creationScripts) {
                    await transaction.execute(sql);
                }
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
    }

    async doTransaction(operations: (transaction: relationalStore.Transaction) => Promise<void>) {
        Logger.Debug(TAG, 'doTransaction: enter');
        if (!this.store) {
            Logger.Error(TAG, `doTransaction: store is undefined`);
            return;
        }

        let transaction: relationalStore.Transaction;
        try {
            transaction = await this.store.createTransaction();
        } catch (error) {
            Logger.Error(TAG, `doTransaction: failed to create transaction: ${JSON.stringify(error)}`);
            return;
        }

        try {
            await operations(transaction);
        } catch (e) {
            Logger.Error(TAG, `doTransaction: failed to execute operations: ${JSON.stringify(e)}`);
            await transaction.rollback();
            return;
        }

        try {
            await transaction.commit();
        } catch (error) {
            Logger.Error(TAG, `doTransaction: failed to commit transaction: ${JSON.stringify(error)}`);
        }
        Logger.Debug(TAG, 'doTransaction: completed');
    }

    async getItems<T extends DBItem>(factory: DBObjectCreator<T>): Promise<T[]> {
        Logger.Info(TAG, 'getObjects: enter');
        if (!this.store) {
            Logger.Error(TAG, `getObjects: store is undefined`);
            return [];
        }

        let result: T[] = [];
        try {
            let resultSet = await this.store.query(new relationalStore.RdbPredicates(factory.getTableName()));
            while (resultSet.goToNextRow()) {
                let bucket = resultSet.getRow();
                result.push(factory.createFromBucket(bucket));
            }
        } catch (error) {
            Logger.Error(TAG, `getObjects: failed to read result set: ${JSON.stringify(error)}`);
        }

        Logger.Info(TAG, `getObjects: completed, found ${result.length} accounts`);
        return result;
    }

    async storeItem(object: DBItem): Promise<void> {
        Logger.Info(TAG, 'storeObject: enter');
        if (!this.store) {
            Logger.Error(TAG, `storeObject: store is undefined`);
            return;
        }

        let bucket = object.toBucket();
        try {
            await this.store.insert(object.getTableName(), bucket);
        } catch (error) {
            Logger.Error(TAG, `storeObject: failed to insert account: ${JSON.stringify(error)}`);
            return;
        }
        Logger.Info(TAG, 'storeObject: completed');
    }
}
