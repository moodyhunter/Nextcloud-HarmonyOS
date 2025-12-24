import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger, NCommon } from 'nextcloud';
import { Constants, FolderViewMode } from '../utils/Common';
import { GlobalStorage } from '../utils/GlobalStorage';

import { Notification } from '../utils/NotificationManager';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { deviceInfo } from '@kit.BasicServicesKit';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
    id: number = 0;

    async onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam) {
        Logger.Info(TAG, 'Ability onCreate');
        try {
            this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        } catch (error) {
            Logger.Error(TAG, `failed to set color mode!`);
        }
        NCommon.Initialise(this.context);
    }

    onDestroy() {
        Logger.Info(TAG, 'Ability onDestroy');
    }

    async onWindowStageCreate(windowStage: window.WindowStage) {
        Logger.Info(TAG, 'Main window is created, set main page for this ability');

        let context = this.context;
        GlobalStorage.SandboxBasePath = context.filesDir;

        try {
            let isPc = deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_2IN1;
            let page = isPc ? 'pages/PcMainPage' : 'pages/Index';
            if (!isPc) {
                GlobalStorage.pHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
                await Notification.startNotification(this.context);
            }
            await windowStage.loadContent(page);
            if (isPc) {
                PersistentStorage.persistProp(Constants.PC_CLOUD_DISK_PATH, '');
            } else {
                PersistentStorage.persistProp(Constants.VIEW_MODE_KEY, FolderViewMode.TwoColumns);
            }
            Logger.Info(TAG, 'Succeeded in loading the content.');
        } catch (e) {
            Logger.Error(TAG, 'Failed to load the content. Cause: ' + JSON.stringify(e) ?? '');
            return;
        }

        Logger.Info(TAG, 'Main window created.');
    }


    onWindowStageDestroy() {
        Logger.Info(TAG, 'Main window is destroyed, release UI related resources');
    }


    async onForeground() {
        Logger.Info(TAG, 'Ability has brought to foreground');
    }

    async onWillBackground() {
        Logger.Info(TAG, 'Ability has back to background');
    }

    onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
        Logger.Info(TAG, `onMemoryLevel: level = ${AbilityConstant.MemoryLevel[level]}`);
    }
};
