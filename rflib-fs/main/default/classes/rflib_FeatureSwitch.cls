/*
 * Copyright (c) 2021 Johannes Fischer <fischer.jh@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name "RFLIB", the name of the copyright holder, nor the names of its
 *    contributors may be used to endorse or promote products derived from
 *    this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @group Feature Switch
 * @description Use this class to retrieve hierarchical feature switch values. 
 */ 
@SuppressWarnings('PMD.ClassNamingConventions')
public without sharing class rflib_FeatureSwitch {
    
    private static final rflib_Logger LOGGER = rflib_LoggerUtil.getFactory().createLogger('rflib_FeatureSwitch');

    private static final String NO_PROFILE = '__NO_PROFILE__';
    
    @TestVisible
    private static final String GLOBAL_SCOPE = '__GLOBAL__';

    @TestVisible
    private static Boolean DEFAULT_VALUE = Test.isRunningTest();

    @TestVisible
    private static Map<String, Map<String, Boolean>> featureSwitches {
        get {
            if (featureSwitches == null) {
                featureSwitches = getAllFeatureSwitches();
            }
            return featureSwitches;
        }
        private set;
    }

    @TestVisible
    private static List<String> directPublicGroupAssociations {
        get {
            if (directPublicGroupAssociations == null) {
                directPublicGroupAssociations = getAllDirectPublicGroupAssociationsForUser();
            }
            return directPublicGroupAssociations;
        }
        private set;
    }

    private static String CACHED_PROFILE_NAME = null;

    /**
     * Returns whether a feature switch is turned on or not. The evaluation will consider the proper
     * hierarchy of the settings, meaning it will return either the value specifically configured for
     * the current user, the current user's profile, or the global fallback. 
     *
     * If the switch is not configured in the Custom Metadata for the user's hierarchy, the return value
     * will be `false`.
     * 
     * @param switchName The name of the feature switch to be evaluated.
     * @return A `Boolean` value indicating if the switch is turned ON.
     */
    public static Boolean isTurnedOn(String switchName) {
        LOGGER.trace('Evaluating feature switch ' + switchName);

        Boolean result = getFeatureSwitchValue(switchName);

        LOGGER.debug('Feature switch {0} is turned on? {1}', new Object[] { switchName, result });

        return result;
    } 

    /**
     * Returns whether a feature switch is turned off or not. The evaluation will consider the proper
     * hierarchy of the settings, meaning it will return either the value specifically configured for
     * the current user, the current user's profile, or the global fallback. 
     *
     * If the switch is not configured in the Custom Metadata for the user's hierarchy, the return value
     * will be `true`.
     * 
     * @param switchName The name of the feature switch to be evaluated.
     * @return A `Boolean` value indicating if the switch is turned OFF.
     */
    public static Boolean isTurnedOff(String switchName) {
        LOGGER.trace('Evaluating feature switch ' + switchName);

        Boolean result = getFeatureSwitchValue(switchName) == false;

        LOGGER.debug('Feature switch {0} is turned off? {1}', new Object[] { switchName, result });

        return result;
    } 

    /**
     * Returns a `Map` of all switch values configured for the current user,
     * considering the hierarchy of each switch value.  
     * 
     * @return A `Map<String, Boolean>` of all configured switches and their value for the given user.
     */
    public static Map<String, Boolean> getAllScopedValues() {
        Map<String, Boolean> result = new Map<String, Boolean>();

        for (String key : featureSwitches.keySet()) {
            result.put(key, getFeatureSwitchValue(key));
        }

        LOGGER.trace('Created fully scoped feature switch map: ' + result);
        return result;
    }

    private static Boolean getFeatureSwitchValue(String switchName) {
        if (!featureSwitches.containsKey(switchName)) {
            return DEFAULT_VALUE;
        }

        Map<String, Boolean> scopedFeatureSwitchValues = featureSwitches.get(switchName);
        if (scopedFeatureSwitchValues.containsKey(UserInfo.getUserName())) {
            return scopedFeatureSwitchValues.get(UserInfo.getUserName());
        }

        for (String groupName : directPublicGroupAssociations) {
            if (scopedFeatureSwitchValues.containsKey(groupName)) {
                return scopedFeatureSwitchValues.get(groupName);
            }
        }

        String profileName = getProfileName(UserInfo.getProfileId());
        if (scopedFeatureSwitchValues.containsKey(profileName)) {
            return scopedFeatureSwitchValues.get(profileName);
        }

        return scopedFeatureSwitchValues.containsKey(GLOBAL_SCOPE)
            ? scopedFeatureSwitchValues.get(GLOBAL_SCOPE)
            : DEFAULT_VALUE;
    }

    private static String getProfileName(Id profileId) {
        if (CACHED_PROFILE_NAME == null) {
            // NO_PROFILE is used for a possible system user context.
            List<Profile> profiles = [SELECT Name FROM Profile WHERE Id = :profileId];
            CACHED_PROFILE_NAME = profiles.size() == 0 ?
                NO_PROFILE :
                profiles.get(0).Name;
        }

        return CACHED_PROFILE_NAME;
    }

    private static Map<String, Map<String, Boolean>> getAllFeatureSwitches() {
        List<rflib_Feature_Switch__mdt> allFeaturesSwitches = rflib_Feature_Switch__mdt.getAll().values();

        LOGGER.trace('All feature switch values: ' + JSON.serialize(allFeaturesSwitches));

        Map<String, Map<String, Boolean>> result = new Map<String, Map<String, Boolean>>();
        for (rflib_Feature_Switch__mdt featureSwitch : allFeaturesSwitches) {
            if (!result.containsKey(featureSwitch.Switch_Name__c)) {
                result.put(featureSwitch.Switch_Name__c, new Map<String, Boolean>());
            }

            Map<String, Boolean> scopedSwitchSettings = result.get(featureSwitch.Switch_Name__c);
            if (featureSwitch.Scope_type__c == 'Global') {
                scopedSwitchSettings.put(GLOBAL_SCOPE, featureSwitch.Turned_On__c);
            } else {
                scopedSwitchSettings.put(featureSwitch.Scope_Name__c, featureSwitch.Turned_On__c);
            }
        }

        return result;
    }

    private static List<String> getAllDirectPublicGroupAssociationsForUser() {
        Id userId = UserInfo.getUserId();
        List<GroupMember> groupMemberships = [SELECT GroupId, Group.DeveloperName FROM GroupMember WHERE UserOrGroupId= :userId AND Group.Type = 'Regular' ORDER BY Group.DeveloperName ASC];

        LOGGER.debug('Group memberships=' + groupMemberships);

        List<String> result = new List<String>();
        for (GroupMember gm : groupMemberships) {
            result.add(gm.Group.DeveloperName);
        }

        return result;
    }

    private rflib_FeatureSwitch() {
        // do nothing
    }
}
