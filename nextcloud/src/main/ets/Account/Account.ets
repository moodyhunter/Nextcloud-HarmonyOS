import { DBAccount } from '../Database/Types/DBAccount';
import { Logger } from '../Utils/Logger';

const TAG = 'SyncEngine/Account';

export class Account {
    dbAccount: DBAccount;

    constructor(dbAccount: DBAccount) {
        Logger.Info(TAG, `constructor: enter`);
        this.dbAccount = dbAccount;
    }
}
