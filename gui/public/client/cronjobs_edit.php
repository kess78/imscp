<?php
/**
 * i-MSCP a internet Multi Server Control Panel
 *
 * @copyright 	2001-2006 by moleSoftware GmbH
 * @copyright 	2006-2010 by ispCP | http://isp-control.net
 * @copyright 	2010 by i-MSCP | http://i-mscp.net
 * @version 	SVN: $Id$
 * @link 		http://i-mscp.net
 * @author 		ispCP Team
 * @author 		i-MSCP Team
 *
 * @license
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is "VHCS - Virtual Hosting Control System".
 *
 * The Initial Developer of the Original Code is moleSoftware GmbH.
 * Portions created by Initial Developer are Copyright (C) 2001-2006
 * by moleSoftware GmbH. All Rights Reserved.
 * Portions created by the ispCP Team are Copyright (C) 2006-2010 by
 * isp Control Panel. All Rights Reserved.
 * Portions created by the i-MSCP Team are Copyright (C) 2010 by
 * i-MSCP a internet Multi Server Control Panel. All Rights Reserved.
 */

require 'imscp-lib.php';

iMSCP_Events_Manager::getInstance()->dispatch(iMSCP_Events::onClientScriptStart);

check_login(__FILE__);

$cfg = iMSCP_Registry::get('config');

$tpl = new iMSCP_pTemplate();
$tpl->define_dynamic('page', $cfg->CLIENT_TEMPLATE_PATH . '/cronjobs_edit.tpl');
$tpl->define_dynamic('page_message', 'page');
$tpl->define_dynamic('logged_from', 'page');

$tpl->assign(
	array(
		'TR_CLIENT_CRONJOBS_TITLE' => tr('i-MSCP - Client/Cronjob Manager'),
		'THEME_COLOR_PATH' => "../themes/{$cfg->USER_INITIAL_THEME}",
		'THEME_CHARSET' => tr('encoding'),
		'ISP_LOGO' => get_logo($_SESSION['user_id'])
	)
);

/**
 * @todo Implement this function
 */
function update_cron_job($tpl, $cron_id) {
} // End of update_cron_job()

/**
 * @todo Implement this function
 */
function gen_cron_job($tpl, $user_id) {
} // End of gen_cron_job()

/*
 *
 * static page messages.
 *
 */

gen_client_mainmenu($tpl, $cfg->CLIENT_TEMPLATE_PATH . '/main_menu_webtools.tpl');
gen_client_menu($tpl, $cfg->CLIENT_TEMPLATE_PATH . '/menu_webtools.tpl');

gen_logged_from($tpl);

check_permissions($tpl);

if (isset($_GET['cron_id']) && is_numeric($_GET['cron_id'])) {
	update_cron_job($tpl, $_GET['cron_id']);
}
gen_cron_job($tpl, $_SESSION['user_id']);

$tpl->assign(
	array(
		'TR_CRON_MANAGER' => tr('Cronjob Manager'),
		'TR_EDIT_CRONJOB' => tr('Edit Cronjob'),
		'TR_NAME' => tr('Name'),
		'TR_DESCRIPTION' => tr('Description'),
		'TR_ACTIVE' => tr('Active'),
		'YES' => tr('Yes'),
		'NO' => tr('No'),
		'TR_CRONJOB' => tr('Cronjob'),
		'TR_COMMAND' => tr('Command to run:'),
		'TR_MIN' => tr('Minute(s):'),
		'TR_HOUR' => tr('Hour(s):'),
		'TR_DAY' => tr('Day(s):'),
		'TR_MONTHS' => tr('Month(s):'),
		'TR_WEEKDAYS' => tr('Weekday(s):'),
		'TR_UPDATE' => tr('Update'),
		'TR_CANCEL' => tr('Cancel'),
	)
);

generatePageMessage($tpl);

$tpl->parse('PAGE', 'page');

iMSCP_Events_Manager::getInstance()->dispatch(
    iMSCP_Events::onClientScriptEnd, new iMSCP_Events_Response($tpl));

$tpl->prnt();

unsetMessages();
