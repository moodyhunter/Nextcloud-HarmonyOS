import { relationalStore } from '@kit.ArkData';
import { Logger } from '../Utils/Logger';
import { DBAccountTableInfo } from './DbTypes/DBAccount';
import { DBLocalSyncFolderTable } from './DbTypes/DBLocalFolder';
import { DBRemoteFolderTable } from './DbTypes/DBRemoteFolder';
import { DEBUG } from '../../../../BuildProfile';
import { DBSyncConfigurationTable } from './DbTypes/DBSyncConfiguration';

const TAG = 'Database/DBManager';

const CAN_RECREATE_DATABASE = true;

interface ForeignKeyDescriptor {
    target: DBTableDescriptor<string, DBItem>;
    targetColumn: ColumnDescriptor;
}

export interface ColumnDescriptor {
    type: string; ///< Data type (e.g., INTEGER, TEXT)
    attrs?: string; ///< Additional attributes (e.g., PRIMARY KEY, NOT NULL)
    foreignKey?: ForeignKeyDescriptor;
}

export interface DBTableDescriptor<TColumnName extends string, TItem> {
    readonly tableName: string,
    readonly columns: Record<TColumnName, ColumnDescriptor>;
    readonly createItemFromBucket: (bucket: relationalStore.ValuesBucket) => TItem;
}

/**
 * Interface for database items that can be converted to a ValuesBucket.
 */
export interface DBItem {
    getTableName(): string;

    toBucket(isCreate: boolean): relationalStore.ValuesBucket;
}

const TABLES: DBTableDescriptor<string, DBItem>[] = [
    DBAccountTableInfo,
    DBRemoteFolderTable,
    DBLocalSyncFolderTable,
    DBSyncConfigurationTable,
];

export class DBManager {
    private store: relationalStore.RdbStore | undefined = undefined;

    static generateTableCreationScript(tableName: string, columnDesc: Record<string, ColumnDescriptor>): string {
        let foreignKeyDefs: string[] = [];
        let columnsDef: string[] = [];
        for (let colName of Object.keys(columnDesc)) {
            let colDesc = columnDesc[colName];
            let colDef = `${colName} ${colDesc.type}`;
            if (colDesc.attrs) {
                colDef += ` ${colDesc.attrs}`;
            }
            columnsDef.push(colDef);
            if (colDesc.foreignKey) {
                let fk = colDesc.foreignKey;
                let fkTargetColumn: string = Object.keys(fk.target.columns).find(key => fk.target.columns[key] === fk.targetColumn)!;
                foreignKeyDefs.push(`FOREIGN KEY(${colName}) REFERENCES ${fk.target.tableName}(${fkTargetColumn})`);
            }
        }
        columnsDef.push(...foreignKeyDefs); // Add foreign key definitions to columns at the end
        return `CREATE TABLE ${tableName} (\n\t${columnsDef.join(',\n\t')});`;
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
                for (let tableDesc of TABLES) {
                    let createSql = DBManager.generateTableCreationScript(tableDesc.tableName, tableDesc.columns);
                    Logger.Info(TAG, `upgradeDatabase: creating table with sql: ${createSql}`);
                    let result = await transaction.execute(createSql);
                    Logger.Info(TAG, `upgradeDatabase: created table ${tableDesc.tableName}, result: ${JSON.stringify(result)}`);
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

    async getItems<T extends DBItem>(factory: DBTableDescriptor<string, T>): Promise<T[]> {
        Logger.Info(TAG, 'getObjects: enter');
        if (!this.store) {
            Logger.Error(TAG, `getObjects: store is undefined`);
            return [];
        }

        let result: T[] = [];
        try {
            let resultSet = await this.store.query(new relationalStore.RdbPredicates(factory.tableName));
            while (resultSet.goToNextRow()) {
                let bucket = resultSet.getRow();
                result.push(factory.createItemFromBucket(bucket));
            }
        } catch (error) {
            Logger.Error(TAG, `getObjects: failed to read result set: ${JSON.stringify(error)}`);
        }

        Logger.Info(TAG, `getObjects: completed, found ${result.length} accounts`);
        return result;
    }

    async getItemById<T extends DBItem>(id: number, column: ColumnDescriptor, factory: DBTableDescriptor<string, T>): Promise<T | null> {
        Logger.Info(TAG, 'getItemById: enter');
        if (!this.store) {
            Logger.Error(TAG, `getItemById: store is undefined`);
            return null;
        }

        let predicate = new relationalStore.RdbPredicates(factory.tableName);
        predicate.equalTo(Object.keys(factory.columns).find(key => factory.columns[key] === column)!, id);

        try {
            let resultSet = await this.store.query(predicate);
            if (resultSet.rowCount === 0) {
                Logger.Warn(TAG, `getItemById: no item found with id=${id}`);
                return null;
            }
            if (resultSet.goToNextRow()) {
                let bucket = resultSet.getRow();
                let item = factory.createItemFromBucket(bucket);
                Logger.Info(TAG, `getItemById: completed, found item with id=${id}`);
                return item;
            }
        } catch (error) {
            Logger.Error(TAG, `getItemById: failed to read result set: ${JSON.stringify(error)}`);
            return null;
        }

        Logger.Info(TAG, `getItemById: completed, no item found with id=${id}`);
        return null;
    }

    async deleteItemById(id: number, object: DBItem): Promise<void> {
        Logger.Info(TAG, 'deleteItemById: enter');
        if (!this.store) {
            Logger.Error(TAG, `deleteItemById: store is undefined`);
            return;
        }

        let predicate = new relationalStore.RdbPredicates(object.getTableName());
        let bucket = object.toBucket(false);
        let idColumnName = Object.keys(bucket).find(key => bucket[key] === id);
        predicate.equalTo(idColumnName!, id);

        try {
            let deletedCount = await this.store.delete(predicate);
            Logger.Info(TAG, `deleteItemById: completed, deleted ${deletedCount} rows from table ${object.getTableName()}`);
        } catch (error) {
            Logger.Error(TAG, `deleteItemById: failed to delete from table ${object.getTableName()}: ${JSON.stringify(error)}`);
        }

    }

    async createItem(object: DBItem): Promise<number | undefined> {
        return this.doStoreItem(object, true);
    }

    async updateItem(object: DBItem): Promise<number | undefined> {
        return this.doStoreItem(object, false);
    }

    async dropDatabase() {
        if (this.store === undefined) {
            Logger.Error(TAG, `dropAllTables: store is undefined`);
            return;
        }

        Logger.Warn(TAG, `dropAllTables: enter, CAN_RECREATE_DATABASE=${CAN_RECREATE_DATABASE}, DEBUG=${DEBUG}`);
        if (CAN_RECREATE_DATABASE && DEBUG) {
            Logger.Warn(TAG, 'upgradeDatabase: recreating database as per ALWAYS_RECREATE_DATABASE flag');
            try {
                for (let tableDesc of TABLES) {
                    let dropSql = `DROP TABLE IF EXISTS ${tableDesc.tableName};`;
                    await this.store.execute(dropSql);
                    Logger.Warn(TAG, `dropAllTables: dropped table ${tableDesc.tableName}`);
                }
                await this.store.execute('PRAGMA user_version = 0');
                Logger.Warn(TAG, 'dropAllTables: reset user_version to 0');
                // drop all other tables
                let tablesResult = await this.store.querySql('SELECT name FROM sqlite_master WHERE type="table";');
                Logger.Warn(TAG, `dropAllTables: checking for leftover tables: ${tablesResult.rowCount}`);
                while (tablesResult.goToNextRow()) {
                    let row = tablesResult.getRow();
                    let tableName = row['name'] as string;
                    Logger.Warn(TAG, `dropAllTables: leftover table ${tableName}`);
                    if (tableName === 'sqlite_sequence') {
                        Logger.Warn(TAG, `dropAllTables: skipping sqlite_sequence table`);
                        continue;
                    }
                    await this.store.execute(`DROP TABLE IF EXISTS ${tableName};`);
                }
                Logger.Warn(TAG, 'dropAllTables: database dropped, closing store');
                await this.store.close();
            } catch (e) {
                Logger.Error(TAG, `dropAllTables: failed to execute sql: ${JSON.stringify(e)}`);
            }
            Logger.Warn(TAG, 'dropAllTables: completed');
        } else {
            Logger.Warn(TAG, 'dropAllTables: operation is disabled');
        }
    }

    private async doStoreItem(object: DBItem, isCreate: boolean): Promise<number | undefined> {
        Logger.Info(TAG, `doStoreItem: enter, isCreate=${isCreate}`);
        if (!this.store) {
            Logger.Error(TAG, `doStoreItem: store is undefined`);
            return;
        }

        let bucket = object.toBucket(isCreate);
        try {
            let rowId = await this.store.insert(object.getTableName(), bucket);
            Logger.Info(TAG, `doStoreItem: completed, rowId: ${rowId}`);
            return rowId;
        } catch (error) {
            Logger.Error(TAG, `doStoreItem: failed to insert to table ${object.getTableName()}: ${JSON.stringify(error)}`);
            return;
        }
    }
}
