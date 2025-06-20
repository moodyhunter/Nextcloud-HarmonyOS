import hilog from '@ohos.hilog';
import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class PermissionManager {
    static async RequestPermission(context: Context, permission: Permissions): Promise<boolean> {
        let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();

        if (await PermissionManager.verifyPermission(permission)) {
            hilog.info(0x0000, 'testTag', `requestPermission success, permissionName->${permission}`);
            return true;
        }

        let result = await atManager.requestPermissionsFromUser(context, [permission]);

        for (let i = 0; i < result.permissions.length; i++) {
            let rPerm = result.permissions[i];
            let rResult = result.authResults[i];

            if (rPerm == permission && rResult == abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
                hilog.info(0x0000, 'testTag', `requestPermission success, permissionName->${permission}`);
                return true;
            }
        }

        hilog.warn(0x0000, 'testTag', `requestPermission fail, ${permission}, requesting to open settings`);
        await AlertDialog.show({ message: '请开启权限' });
        await atManager.requestPermissionOnSetting(context, [permission]);
        return false;
    }

    private static async verifyPermission(permission: Permissions): Promise<boolean> {
        let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
        let tokenID: number = (await
        bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION))
            .appInfo
            .accessTokenId;
        let result: boolean = false;
        await atManager.verifyAccessToken(tokenID, permission).then((data: abilityAccessCtrl.GrantStatus) => {
            result = data == abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
        }).catch((err: BusinessError) => {
            hilog.error(0x0000, 'testTag', `verifyPermission fail, err->${JSON.stringify(err)}`);
        });
        return result;
    }
}
