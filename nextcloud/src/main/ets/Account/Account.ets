// Describes a logged in user

const TAG = 'SyncEngine/Account';

export class Account {
    id: string;
    username: string;
    password: string;
    hostname: string;

    constructor(id: string, username: string, password: string, hostname: string) {
        this.id = id;
        this.username = username;
        this.password = password;
        this.hostname = hostname;
    }

    static ReadFromRecord(): Account {
        return new Account('', '', '', '');
    }
}
