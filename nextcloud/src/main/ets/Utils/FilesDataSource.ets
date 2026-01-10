import { BasicDataSource } from './BasicDatasource';
import { DirectoryEntry } from '../webdav/DirEntryParserStateMachine';
import { ListFiles } from '../webdav/Files';
import { Account } from '../Account/Account';

export class FilesDataSource extends BasicDataSource<DirectoryEntry> {
    constructor(account: Account, path: string) {
        super();
        ListFiles(account, path).then(entries => {
            entries = entries.sort((a: DirectoryEntry, b: DirectoryEntry) => {
                // Directories first, then sort by name
                if (a.isDirectory && !b.isDirectory) {
                    return -1;
                } else if (!a.isDirectory && b.isDirectory) {
                    return 1;
                } else {
                    return a.name.localeCompare(b.name);
                }
            })

            this.entries = entries;
            this.notifyDataReload();
        });
    }
}
