@IsTest
private class SFDCSecurityUtilsTest {

    @IsTest
    static void testCheckObjectReadFail() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                Boolean excThrown = false;
                try {
                    SFDCSecurityUtils.checkRead(Account.SObjectType, new List<String>{'ParentId'});
                } catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assert(excThrown);
            }
        }
    }

    @IsTest
    static void testCheckObjectInsertFail() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                Boolean excThrown = false;
                try {
                    SFDCSecurityUtils.checkInsert(Account.SObjectType, new List<String>{'ParentId'});
                } catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assert(excThrown);
            }
        }
    }

    @IsTest
    static void testCheckObjectUpdateFail() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                Boolean excThrown = false;
                try {
                    SFDCSecurityUtils.checkUpdate(Account.SObjectType, new List<String>{'ParentId'});
                } catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assert(excThrown);
            }
        }
    }

    @IsTest
    static void testInsertCheckCRUDAndFLS() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                Account testAcct = new Account(Name = 'Test Account');

                Boolean excThrown = false;
                try {
                    SFDCSecurityUtils.insertCheckCRUDAndFLS(testAcct, new List<String>());
                } catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assert(excThrown);
            }
        }
    }

    @IsTest
    static void testUpdateCheckCRUDAndFLS() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                Account testAcct = new Account(Name = 'Test Account');

                Boolean excThrown = false;
                try {
                    SFDCSecurityUtils.insertProxy(testAcct);
                } catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assertNotEquals(true, excThrown);

                try {
                    SFDCSecurityUtils.updateCheckCRUDAndFLS(testAcct, new List<String>());
                }
                catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assertEquals(true, excThrown);
            }
        }
    }

    @IsTest
    static void testDeleteCheckCRUDAndFLS() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                Account testAcct = new Account(Name = 'Test Account');

                Boolean excThrown = false;
                try {
                    SFDCSecurityUtils.insertProxy(testAcct);
                } catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assertNotEquals(true, excThrown);

                excThrown = false;
                try {
                    SFDCSecurityUtils.deleteCheckCRUDAndFLS(new List<Account>{testAcct}, false);
                }
                catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assertEquals(true, excThrown);
            }
        }
    }

    @IsTest
    static void testUnableToCheckCrudFlsError() {
        Account testAcct = new Account(Name = 'Test Account');

        SFDCSecurityUtils.SecurityException securityException;
        try {
            SFDCSecurityUtils.insertCheckCRUDAndFLS(new List<SObject>{testAcct}, new List<String>());
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            securityException = ex;
        }

        System.assertNotEquals(NULL, securityException);

        Boolean excThrown = false;
        try {
            SFDCSecurityUtils.insertProxy(testAcct);
        }
        catch (Exception ex) {
            excThrown = true;
        }

        System.assertNotEquals(true, excThrown);

        securityException = NULL;
        try {
            SFDCSecurityUtils.updateCheckCRUDAndFLS(new List<SObject>{testAcct}, new List<String>());
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            securityException = ex;
        }
        System.assertNotEquals(NULL, securityException);

        securityException = NULL;
        try {
            SFDCSecurityUtils.deleteCheckCRUDAndFLS(new List<SObject>{testAcct});
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            securityException = ex;
        }
        System.assertNotEquals(NULL, securityException);

        securityException = NULL;
        try {
            SFDCSecurityUtils.upsertCheckCRUDAndFLS(new List<SObject>{testAcct}, new List<String>());
        }
        catch (SFDCSecurityUtils.SecurityException ex) {
            securityException = ex;
        }
        System.assertNotEquals(NULL, securityException);
    }

    @IsTest
    static void testCheckFLS() {
        User usr = createTestUserNoAccess();
        if (usr != NULL) {
            System.runAs(usr) {
                Account testAcct = new Account(Name = 'Test Account');

                Boolean excThrown = false;
                try {
                    SFDCSecurityUtils.insertProxy(testAcct);
                } catch (SFDCSecurityUtils.CrudException e) {
                    excThrown = true;
                }
                System.assertNotEquals(true, excThrown);

                SFDCSecurityUtils.FlsInspectionResult readResult = SFDCSecurityUtils.checkFieldIsReadable(
                    Account.SObjectType,
                    'ParentId'
                );
                System.assertEquals(true, readResult.inspectionFailed);

                SFDCSecurityUtils.FlsInspectionResult insResult = SFDCSecurityUtils.checkFieldIsInsertable(
                    Account.SObjectType,
                    'ParentId'
                );
                System.assertEquals(true, insResult.inspectionFailed);

                SFDCSecurityUtils.FlsInspectionResult updResult = SFDCSecurityUtils.checkFieldIsUpdateable(
                    Account.SObjectType,
                    'ParentId'
                );
                System.assertEquals(true, updResult.inspectionFailed);
            }
        }
    }

    @IsTest
    static void testProxyDML() {
        Account testAcct = new Account(Name = 'Test Account');
        SFDCSecurityUtils.insertProxy(testAcct);
        testAcct.Name = 'Test Account Updated';
        SFDCSecurityUtils.updateProxy(testAcct);
        System.assertEquals('Test Account Updated', [SELECT Name FROM Account WHERE Id = :testAcct.Id].Name);
        SFDCSecurityUtils.deleteProxy(testAcct);
        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE Id = :testAcct.Id]);
    }

    public static User createTestUserNoAccess() {
        User usr;
        try {
            //look for a profile that does not have access to the Account object
            PermissionSet ps = [
                SELECT Profile.Id, Profile.Name
                FROM PermissionSet
                WHERE IsOwnedByProfile = true
                AND Profile.UserType = 'Standard'
                AND Id NOT IN (SELECT ParentId FROM ObjectPermissions WHERE SObjectType = 'Account' AND PermissionsRead = true)
                LIMIT 1
            ];

            if (ps != NULL) {
                //create a user with the profile found that doesn't have access to the Account object
                usr = new User(
                    FirstName = 'testUsrF',
                    LastName = 'testUsrL',
                    Alias = 'tstUsr',
                    Email = 'testy.test@test.com',
                    UserName = 'test' + Math.random().format() + 'user99@test.com',
                    EmailEncodingKey = 'ISO-8859-1',
                    LanguageLocaleKey = 'en_US',
                    TimeZoneSidKey = 'America/Los_Angeles',
                    LocaleSidKey = 'en_US',
                    ProfileId = ps.Profile.Id,
                    IsActive = true
                );
                insert usr;
            }
        } catch (Exception e) {
            //do nothing, just return NULL User because this test case won't work in this org.
            return NULL;
        }
        return usr;
    }

}