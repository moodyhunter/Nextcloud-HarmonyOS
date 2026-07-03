import { rcp } from '@kit.RemoteCommunicationKit';
import { Logger } from '../Utils/Logger';
import { NCommon } from '../Common';
import { xml } from '@kit.ArkTS';
import { DirectoryEntry, DirEntryParserStateMachine } from './DirEntryParserStateMachine';
import { Account } from '../Account/Account';

const TAG = 'webdav/Files';

let session: rcp.Session | null = null;

export async function ListFiles(account: Account, path: string): Promise<DirectoryEntry[]> {
    let url = account.remoteBaseDirUrl() + path;
    Logger.Info(TAG, "Listing files at " + path);

    let sessionConfiguration: rcp.SessionConfiguration = {
        headers: {
            'authorization': account.makeAuthorizationHeader(),
            'user-agent': NCommon.UserAgent(),
            'accept': 'text/plains'
        }
    };

    if (!session) {
        session = rcp.createSession(sessionConfiguration);
    }

    let req =
        new rcp.Request(url, "PROPFIND", {},
            '<?xml version="1.0" encoding="UTF-8"?>\n' +
                '        <d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns">\n' +
                '            <d:prop>\n' +
                '                <d:getlastmodified/>\n' +
                '                <d:getcontentlength/>\n' +
                '                <d:getcontenttype/>\n' +
                '                <oc:permissions/>\n' +
                '                <oc:fileid/>\n' +
                '                <nc:has-preview/>\n' +
                '                <d:resourcetype/>\n' +
                '                <d:getetag/>\n' +
                '            </d:prop>\n' +
                '        </d:propfind>');

    let resp = await session.fetch(req);
    if (!resp.body) {
        Logger.Error(TAG, "Failed to fetch");
        return [];
    }

    let parser = new xml.XmlPullParser(resp.body);
    let machine = new DirEntryParserStateMachine();

    let options: xml.ParseOptions = {
        supportDoctype: true,
        ignoreNameSpace: true,
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo) => {
            switch (eventType) {
                case xml.EventType.START_TAG:
                    machine.onStartChildTag(value.getName());
                    break;
                case xml.EventType.END_TAG:
                    machine.onEndTag();
                    break;
                case xml.EventType.TEXT:
                case xml.EventType.ENTITY_REFERENCE:
                    machine.onText(value.getText());
                    break;
            }
            return true;
        }
    };

    parser.parseXml(options)

    const prefix = '/remote.php/dav/files/' + account.username + path;
    return machine.getDirEntryList(prefix);
}
