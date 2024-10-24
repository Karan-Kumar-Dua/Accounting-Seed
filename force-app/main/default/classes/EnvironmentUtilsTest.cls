@IsTest
private with sharing class EnvironmentUtilsTest {
    
    @IsTest
    static void testDatatablesLocaleGerman() {
        User u = createUser('de', 'de_DE');
        System.runAs(u) {
            EnvironmentUtils utils = new EnvironmentUtils();
            System.assertEquals('de-DE', utils.getDatatablesLocale());
        }
    }

    @IsTest
    static void testDatatablesLocaleSwiss() {
        User u = createUser('de', 'de_CH');
        System.runAs(u) {
            EnvironmentUtils utils = new EnvironmentUtils();
            System.assertEquals('de-DE', utils.getDatatablesLocale());
        }
    }

    @IsTest
    static void testDatatablesLocaleFrench() {
        User u = createUser('fr', 'fr_FR');
        System.runAs(u) {
            EnvironmentUtils utils = new EnvironmentUtils();
            System.assertEquals('fr-FR', utils.getDatatablesLocale());
        }
    }

    @IsTest
    static void testDatatablesLocaleFrenchCanadian() {
        User u = createUser('fr', 'fr_CA');
        System.runAs(u) {
            EnvironmentUtils utils = new EnvironmentUtils();
            System.assertEquals('fr-FR', utils.getDatatablesLocale());
        }
    }

    @IsTest
    static void testDatatablesLocaleEnglish() {
        User u = createUser('en_US', 'en_US');
        System.runAs(u) {
            EnvironmentUtils utils = new EnvironmentUtils();
            System.assertEquals('en-US', utils.getDatatablesLocale());
        }
    }

    @IsTest
    static void testDatatablesLocaleJapan() {
        User u = createUser('ja', 'ja_JP');
        System.runAs(u) {
            EnvironmentUtils utils = new EnvironmentUtils();
            System.assertEquals('en-US', utils.getDatatablesLocale());
        }
    }

    static User createUser(String languageLocaleKey, String localeSidKey) {
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User sysAdminUser = new User(
            Alias = 'sysAdmin',
            Email = 'sysAdmin.email@fakemail.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'AcctSeedSysAdmin',
            LanguageLocaleKey = languageLocaleKey,
            LocaleSidKey = localeSidKey,
            ProfileId = sysAdminProfile.Id,
            TimeZoneSidKey = Userinfo.getTimeZone().getID(),
            Username = 'acctSeed.sysAdmin.username@as.acctseed.com' + DateTime.now().getTime()
        );
        insert sysAdminUser;
        return sysAdminUser;
    }

}