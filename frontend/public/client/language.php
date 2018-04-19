<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2018 by Laurent Declercq <l.declercq@nuxwin.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

use iMSCP\TemplateEngine;
use iMSCP_Registry as Registry;

require_once 'imscp-lib.php';

checkLogin('user');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptStart);

$tpl = new TemplateEngine();
$tpl->define('layout', 'shared/layouts/ui.tpl');
$tpl->define([
    'page'                => 'client/language.tpl',
    'page_message'        => 'layout',
    'languages_available' => 'page',
    'def_language'        => 'languages_available'
]);

if (isset($_SESSION['logged_from']) && isset($_SESSION['logged_from_id'])) {
    list($customerCurrentLanguage) = get_user_gui_props($_SESSION['user_id']);
} else {
    $customerCurrentLanguage = $_SESSION['user_def_lang'];
}

if (!empty($_POST)) {
    $customerId = $_SESSION['user_id'];
    $customerNewLanguage = cleanInput($_POST['def_language']);
    in_array($customerNewLanguage, getAvailableLanguages(true), true) or showBadRequestErrorPage();

    if ($customerCurrentLanguage != $customerNewLanguage) {
        execQuery('UPDATE user_gui_props SET lang = ? WHERE user_id = ?', [$customerNewLanguage, $_SESSION['user_id']]);

        if (!isset($_SESSION['logged_from_id'])) {
            unset($_SESSION['user_def_lang']);
            $_SESSION['user_def_lang'] = $customerNewLanguage;
        }

        setPageMessage(tr('Language has been updated.'), 'success');
    } else {
        setPageMessage(tr('Nothing has been changed.'), 'info');
    }

    redirectTo('language.php');
}

$tpl->assign([
    'TR_PAGE_TITLE'      => tr('Client / Profile / Language'),
    'TR_GENERAL_INFO'    => tr('General information'),
    'TR_LANGUAGE'        => tr('Language'),
    'TR_CHOOSE_LANGUAGE' => tr('Choose your language'),
    'TR_UPDATE'          => tr('Update')
]);
generateNavigation($tpl);
generateLanguagesList($tpl, $customerCurrentLanguage);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onClientScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();