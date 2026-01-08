import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { InitialiseNextcloud, Logger, NCommon } from 'nextcloud';
import { Constants, FolderViewMode } from '../utils/Common';
import { GlobalStorage } from '../utils/GlobalStorage';
import { Notification } from '../utils/NotificationManager';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { statusBarManager } from '@kit.DeskTopExtensionKit';

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
        await InitialiseNextcloud(this.context);
    }

    onDestroy() {
        Logger.Info(TAG, 'Ability onDestroy');
    }

    convertToPixelMap(res: Resource) {
        // 获取 resourceManager
        const resManager = this.context.resourceManager;

        // 获取 DrawableDescriptor 并转换为 PixelMap
        const drawableDesc = resManager?.getDrawableDescriptor(res.id) as DrawableDescriptor;
        return drawableDesc?.getPixelMap(); // 直接获取 PixelMap
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
                PersistentStorage.persistProp(Constants.PC_CLOUD_DISK_ALIAS, '');

                // 构建右键菜单项内容
                let subMenus: Array<statusBarManager.StatusBarSubMenuItem> = [];
                let subMenuItemAction: statusBarManager.StatusBarMenuAction = {
                    abilityName: "EntryAbility"
                }
                let subMenu: statusBarManager.StatusBarSubMenuItem = {
                    subTitle: "子菜单项",
                    menuAction: subMenuItemAction
                }
                subMenus.push(subMenu);

                let statusBarMenuItems: Array<statusBarManager.StatusBarMenuItem> = [];
                let menuItem: statusBarManager.StatusBarMenuItem = {
                    title: "一级菜单项",
                    // 一级menuAction和subMenu两项不可都缺省
                    subMenu: subMenus
                };
                statusBarMenuItems.push(menuItem);

                let statusBarGroupMenus: Array<statusBarManager.StatusBarGroupMenu> = [];
                statusBarGroupMenus.push(statusBarMenuItems);

                let img = this.convertToPixelMap($r('app.media.tray_icon'));

                try {
                    statusBarManager.addToStatusBar(this.context, {
                        icons: {
                            black: img,
                            white: img,
                        },
                        quickOperation: {
                            title: this.context.resourceManager.getStringSync($r('app.string.app_name').id),
                            height: 400,
                            abilityName: 'StatusBarAbility',
                        },
                        statusBarGroupMenu: statusBarGroupMenus,
                    });
                } catch (e) {
                    Logger.Error(TAG, `failed to add to status bar: ${JSON.stringify(e)}`);
                }

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

    async onPrepareToTerminateAsync(): Promise<boolean> {
        await this.context.hideAbility();
        return true;
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

    async onMemoryLevel(level: AbilityConstant.MemoryLevel) {
        Logger.Info(TAG, `onMemoryLevel: level = ${AbilityConstant.MemoryLevel[level]}`);
    }
}
