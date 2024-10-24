@IsTest
public with sharing class SelectOptionSorterTest {

    @IsTest
    public static void testDoSortByValue() {
        List<SelectOption> opts = new List<SelectOption>{
            new SelectOption('v1', 'l1'),
            new SelectOption('v5', 'l1'),
            new SelectOption('v2', 'l1'),
            new SelectOption('v6', 'l1'),
            new SelectOption('v8', 'l1')
        };

        SelectOptionSorter.doSort(opts, SelectOptionSorter.FieldToSort.Value);

        System.assertEquals(opts.size(), 5);
        System.assertEquals('v1', opts[0].getValue());
        System.assertEquals('v2', opts[1].getValue());
        System.assertEquals('v5', opts[2].getValue());
        System.assertEquals('v6', opts[3].getValue());
        System.assertEquals('v8', opts[4].getValue());
    }

    @IsTest
    public static void testDoSortByLabel() {
        List<SelectOption> opts = new List<SelectOption>{
            new SelectOption('v1', 'l1'),
            new SelectOption('v5', 'l5'),
            new SelectOption('v2', 'l2'),
            new SelectOption('v2.2', 'l2'), // Same label case
            new SelectOption('v6', 'l6'),
            new SelectOption('v8', 'l8')
        };

        SelectOptionSorter.doSort(opts, SelectOptionSorter.FieldToSort.Label);

        System.assertEquals(opts.size(), 6);
        System.assertEquals('l1', opts[0].getLabel());
        System.assertEquals('l2', opts[1].getLabel());
        System.assertEquals('l2', opts[2].getLabel());
        System.assertEquals('l5', opts[3].getLabel());
        System.assertEquals('l6', opts[4].getLabel());
        System.assertEquals('l8', opts[5].getLabel());
    }

}