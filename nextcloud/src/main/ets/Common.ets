import { deviceInfo } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { Logger } from './Utils/Logger';
import { photoAccessHelper } from '@kit.MediaLibraryKit';


const TAG = "Nextcloud-Common";

const USER_AGENT_PART = "Nextcloud Client for HarmonyOS on ";

type LOGIN_APP_PASSWORD = "login.appPassword";
type LOGIN_USERNAME = "login.username";
type LOGIN_SERVER = "login.server";
type UPLOAD_BASE_DIRECTORY = "upload.baseDir";
type UPLOAD_REPLACE_EXISTING = "upload.replaceExisting";

type SETTINGS_KEYS =
    LOGIN_APP_PASSWORD |
    LOGIN_USERNAME |
    LOGIN_SERVER |
    UPLOAD_BASE_DIRECTORY |
    UPLOAD_REPLACE_EXISTING;

class NPreference {
    private pref: preferences.Preferences;

    constructor(context: Context) {
        this.pref = preferences.getPreferencesSync(context, { name: "nextcloud" });
    }

    get replaceExistingFiles(): boolean {
        return this.getPref('upload.replaceExisting', false);
    }

    set replaceExistingFiles(doReplace: boolean) {
        this.setPref('upload.replaceExisting', doReplace);
    }

    get baseUploadDirectory(): string {
        const DEFAULT_VALUE = 'InstantUpload/';
        let dir = this.getPref('upload.baseDir', DEFAULT_VALUE);
        if (dir === '') {
            dir = DEFAULT_VALUE;
        }
        return dir;
    }

    set baseUploadDirectory(dir: string) {
        this.setPref('upload.baseDir', dir);
    }

    public getPref<T>(key: SETTINGS_KEYS, defaultValue: T): T {
        try {
            let value = this.pref.getSync(key, "") as T;
            if (value === null) {
                Logger.Info(TAG, "No value stored for " + key);
                return defaultValue;
            }
            return value as T;
        } catch (error) {
            Logger.Info(TAG, "No value stored for " + key);
            return defaultValue;
        }

    }

    private setPref(key: SETTINGS_KEYS, value: preferences.ValueType) {
        Logger.Info(TAG, "Storing value for " + key);
        try {
            this.pref.putSync(key, value);
            this.pref.flushSync();
        } catch (error) {
            Logger.Error(TAG, `failed to put and flush preferences: ${JSON.stringify(error)}`);
        }
    }
}


export namespace NCommon {
    /**
     * Preferences for Nextcloud
     */
    export let Preference: NPreference;

    export let pHelper: photoAccessHelper.PhotoAccessHelper;

    export function UserAgent() {
        return USER_AGENT_PART + deviceInfo.marketName + " (" + deviceInfo.productModel + ")";
    }

    /**
     * Initialise the common module
     * @param context The context to use for preferences
     */
    export function Initialise(context: Context) {
        Logger.Info(TAG, "Common initialised with User-Agent: " + UserAgent());
        Preference = new NPreference(context);
    }

    export function RandomString(length: number): string {
        const CHARACTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' + 'abcdefghijklmnopqrstuvwxyz' + '0123456789';
        let result = '';
        const charactersLength = CHARACTERS.length;
        for (let i = 0; i < length; i++) {
            result += CHARACTERS.charAt(Math.floor(Math.random() * charactersLength));
        }
        return result;
    }
}
