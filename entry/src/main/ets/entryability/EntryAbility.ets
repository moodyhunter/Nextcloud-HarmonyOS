import { AbilityConstant, ConfigurationConstant, UIAbility, Want, wantAgent } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AsyncSleep, InitialiseNextcloud, Logger, NCommon, Nextcloud, PhotoAssetsManager } from 'nextcloud';
import { Constants, FolderViewMode } from '../utils/Common';
import { GlobalStorage } from '../utils/GlobalStorage';
import { NotificationManager } from '../utils/NotificationManager';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { statusBarManager } from '@kit.DeskTopExtensionKit';
import { BUNDLE_NAME } from 'BuildProfile';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
    private initCompleted: boolean = false;
    private readonly isPc: boolean;

    constructor() {
        super();
        this.isPc = deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_2IN1;
    }

    async onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam) {
        Logger.Info(TAG, 'Ability onCreate');
        try {
            this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        } catch (error) {
            Logger.Error(TAG, `failed to set color mode!`);
        }
        await InitialiseNextcloud(this.context);
        this.initCompleted = true;
    }

    onDestroy() {
        Logger.Info(TAG, 'Ability onDestroy');
    }

    async onWindowStageCreate(windowStage: window.WindowStage) {
        await this.ensureInitCompleted();
        let context = this.context;
        GlobalStorage.SandboxBasePath = context.filesDir;

        try {
            let page = this.isPc ? 'pages/PcMainPage' : 'pages/Index';
            await this.startBackgroundRunning();
            NCommon.pHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
            PhotoAssetsManager.initialize(Nextcloud.getSyncFolderManager().allLocalFolders);
            await windowStage.loadContent(page);
            if (this.isPc) {
                this.createTrayIcon();
            } else {
                PersistentStorage.persistProp(Constants.VIEW_MODE_KEY, FolderViewMode.TwoColumns);
                PersistentStorage.persistProp(Constants.PHONE_ACTIVE_ACCOUNT_ID, 0);
            }
            Logger.Info(TAG, 'Succeeded in loading the content.');
        } catch (e) {
            Logger.Error(TAG, 'Failed to load the content. Cause: ' + JSON.stringify(e) ?? '');
            return;
        }

        Logger.Info(TAG, 'Main window created.');
    }

    /**
     * @throws
     */
    async onPrepareToTerminateAsync(): Promise<boolean> {
        if (this.isPc) {
            await this.context.hideAbility();
            return true;
        } else {
            return false;
        }
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

    onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
        Logger.Info(TAG, `want: ${JSON.stringify(want)}, ${JSON.stringify(launchParam)}`);
    }

    private async startBackgroundRunning() {
        Logger.Info(TAG, `startBackgroundRunning`);
        try {
            const WANT_AGENT_INFO: wantAgent.WantAgentInfo = {
                wants: [{ bundleName: BUNDLE_NAME, abilityName: "EntryAbility" }],
                actionType: wantAgent.OperationType.START_ABILITY,
                requestCode: 0,
                wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
            };
            let wantAgentObj = await wantAgent.getWantAgent(WANT_AGENT_INFO);
            let req = new backgroundTaskManager.ContinuousTaskRequest();
            req.backgroundTaskModes = [backgroundTaskManager.BackgroundTaskMode.MODE_TASK_KEEPING];
            req.backgroundTaskSubmodes = [backgroundTaskManager.BackgroundTaskSubmode.SUBMODE_NORMAL_NOTIFICATION];
            req.wantAgent = wantAgentObj;

            let res = await backgroundTaskManager.startBackgroundRunning(this.context, req);
            Logger.Info(TAG, `startBackgroundRunning: succeeded: ${JSON.stringify(res)}`);
        } catch (error) {
            let e = error as BusinessError;
            Logger.Error(TAG, `startBackgroundRunning: failed. code is ${e.code} message is ${e.message}`);
        }
    }

    private async ensureInitCompleted() {
        while (!this.initCompleted) {
            Logger.Info(TAG, 'Waiting for initialization to complete...');
            await AsyncSleep(100);
        }
        Logger.Info(TAG, 'Initialization completed, proceeding to create main window.');
    }

    /**
     * Convert Resource to PixelMap
     * @throws
     */
    private convertToPixelMap(res: Resource): PixelMap {
        const resManager = this.context.resourceManager;
        const drawableDesc = resManager?.getDrawableDescriptor(res.id);
        return drawableDesc.getPixelMap();
    }

    private createTrayIcon() {
        const menuItem: statusBarManager.StatusBarMenuItem = {
            title: "Main Window",
            menuAction: {
                abilityName: "EntryAbility",
            }
        };

        try {
            let trayIconImage = this.convertToPixelMap($r('app.media.tray_icon'));
            statusBarManager.addToStatusBar(this.context, {
                icons: {
                    black: trayIconImage,
                    white: trayIconImage,
                },
                quickOperation: {
                    title: this.context.resourceManager.getStringSync($r('app.string.app_name').id),
                    height: 400,
                    abilityName: 'StatusBarAbility',
                },
                statusBarGroupMenu: [[menuItem]],
            });
        } catch (e) {
            Logger.Error(TAG, `failed to add to status bar: ${JSON.stringify(e)}`);
        }
    }
}
