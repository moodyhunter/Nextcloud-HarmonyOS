// Describes the root sync folder that's in the system
import { Account } from "../Account/Account";

const TAG = 'SyncEngine/SyncFolder';

export class SyncFolder {
    id: string;
    alias: string;
    systemPath: string;

    ownerAccount: Account | null = null;

    syncTimerId: number = 0;

    constructor(id: string, alias: string, systemPath: string) {
        this.id = id;
        this.alias = alias;
        this.systemPath = systemPath;
    }

    static ReadFromRecord(): SyncFolder {
        return new SyncFolder('', '', '');
    }
}
