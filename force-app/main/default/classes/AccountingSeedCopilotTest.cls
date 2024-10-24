/**
 * Created by ryansieve on 3/21/24.
 */

@IsTest
private class AccountingSeedCopilotTest {
    @IsTest
    static void testGetContext() {
        Test.startTest();
        Map<String, Object> mContext = AccountingSeedCopilot.getContext();
        Test.stopTest();
        system.assertEquals(UserInfo.getUserId(), mContext.get('UserId'));
        system.assertEquals(UserInfo.getOrganizationId(), mContext.get('OrganizationId'));
    }
}