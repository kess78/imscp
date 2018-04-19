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
use iMSCP_Events as Events;
use iMSCP_Events_Event as Event;
use iMSCP_Registry as Registry;

require 'imscp-lib.php';

checkLogin('reseller');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onResellerScriptStart);
resellerHasFeature('aps') or showBadRequestErrorPage();

$cfg = Registry::get('config');

$tpl = new TemplateEngine();
$tpl->define([
    'layout'                   => 'shared/layouts/ui.tpl',
    'page'                     => 'reseller/software_upload.tpl',
    'page_message'             => 'layout',
    'list_software'            => 'page',
    'no_software_list'         => 'page',
    'webdepot_list'            => 'page',
    'no_webdepotsoftware_list' => 'page',
    'web_software_repository'  => 'page',
    'list_webdepotsoftware'    => 'web_software_repository',
    'package_install_link'     => 'page',
    'package_info_link'        => 'page'
]);

if (ask_reseller_is_allowed_web_depot($_SESSION['user_id']) == "yes") {
    list($use_webdepot, $webdepot_xml_url, $webdepot_last_update) = getSoftwareInstallerConfig();

    if ($use_webdepot) {
        $error = '';

        if (isset($_POST['uaction']) && $_POST['uaction'] == "updatewebdepot") {
            $xml_file = @file_get_contents($webdepot_xml_url);

            if (!strpos($xml_file, 'i-MSCP web software repositories list')) {
                setPageMessage(tr("Unable to read xml file for web software."), 'error');
                $error = 1;
            }

            if (!$error) {
                updateSoftwareWebRepoIndex($webdepot_xml_url, $webdepot_last_update);
            }
        }

        $packages_cnt = getSoftwaresListFromWebRepo($tpl, $_SESSION['user_id']);

        $tpl->assign([
            'TR_WEBDEPOT'                 => tr('i-MSCP Software installer / Web software repository'),
            'TR_APPLY_CHANGES'            => tr('Update from web depot'),
            'TR_PACKAGE_TITLE'            => tr('Package title'),
            'TR_PACKAGE_INSTALL_TYPE'     => tr('Package install type'),
            'TR_PACKAGE_VERSION'          => tr('Package version'),
            'TR_PACKAGE_LANGUAGE'         => tr('Package language'),
            'TR_PACKAGE_TYPE'             => tr('Package type'),
            'TR_PACKAGE_VENDOR_HP'        => tr('Package vendor HP'),
            'TR_PACKAGE_ACTION'           => tr('Package actions'),
            'TR_WEBDEPOTSOFTWARE_COUNT'   => tr('Web software depot packages total'),
            'TR_WEBDEPOTSOFTWARE_ACT_NUM' => $packages_cnt
        ]);

        Registry::get('iMSCP_Application')->getEventsManager()->registerListener(Events::onGetJsTranslations, function (Event $e) {
            $e->getParam('translations')->core['dataTable'] = getDataTablesPluginTranslations(false);
        });

        $tpl->parse('WEBDEPOT_LIST', '.webdepot_list');
    } else {
        $tpl->assign('WEBDEPOT_LIST', '');
    }
} else {
    $tpl->assign('WEBDEPOT_LIST', '');
}

if (isset($_POST['upload']) && $_SESSION['software_upload_token'] == $_POST['send_software_upload_token']) {
    $file = 0;
    $success = 1;
    unset($_SESSION['software_upload_token']);

    if ($_FILES['sw_file']['name'] != '' && !empty($_POST['sw_wget'])) {
        setPageMessage(tr('You must choose between local and remote upload.'), 'error');
        $success = 0;
    } elseif ($_FILES['sw_file']['name'] == '' && empty($_POST['sw_wget'])) {
        setPageMessage(tr('You must select a file to upload.'), 'error');
        $success = 0;
    } else {
        if ($_FILES['sw_file']['name'] && $_FILES['sw_file']['name'] != 'none') {
            if (substr($_FILES['sw_file']['name'], -7) != '.tar.gz') {
                setPageMessage(tr("Only 'tar.gz' archives are accepted."), 'error');
                $success = 0;
            }
        } else {
            if (substr($_POST['sw_wget'], -7) != '.tar.gz') {
                setPageMessage(tr("Only 'tar.gz' archives are accepted."), 'error');
                $success = 0;
            }

            $file = 1;
        }
    }

    if ($success == 1) {
        $upload = 1;

        if ($file == 0) {
            $fname = $_FILES['sw_file']['name'];
        } else {
            $fname = substr($_POST['sw_wget'], (strrpos($_POST['sw_wget'], '/') + 1));
        }

        $filename = substr($fname, 0, -7);
        $extension = substr($fname, -7);

        execQuery(
            "
                INSERT INTO web_software (
                    reseller_id, software_name, software_version, software_language, software_type, software_db, software_archive,
                    software_installfile, software_prefix, software_link, software_desc,software_status
                ) VALUES (
                    ?, 'waiting_for_input', 'waiting_for_input', 'waiting_for_input', 'waiting_for_input', 0, ?,'waiting_for_input',
                    'waiting_for_input', 'waiting_for_input','waiting_for_input', 'toadd'
                )
            ",
            [$_SESSION['user_id'], $filename,]
        );

        /** @var iMSCP_Database $db */
        $db = Registry::get('iMSCP_Application')->getDatabase();

        $softwareId = $db->lastInsertId();

        if ($file == 0) {
            $destDir = $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/softwares/' . $_SESSION['user_id'] . '/' . $filename . '-' . $softwareId .
                $extension;

            if (!is_dir($cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/softwares/' . $_SESSION['user_id'])) {
                @mkdir($cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/softwares/' . $_SESSION['user_id'], 0755, true);
            }

            if (!move_uploaded_file($_FILES['sw_file']['tmp_name'], $destDir)) {
                // Delete software entry
                execQuery('DELETE FROM web_software WHERE software_id = ?', [$softwareId]);

                $sw_wget = '';
                setPageMessage(
                    tr('Could not upload the file. Max. upload filesize (%1$d MB) has been reached.', ini_get('upload_max_filesize')), 'error'
                );
                $upload = 0;
            }
        }

        $softwareWget = '';

        if ($file == 1) {
            $softwareWget = $_POST['sw_wget'];
            $destDir = $cfg['FRONTEND_ROOT_DIR'] . '/data/persistent/softwares/' . $_SESSION['user_id'] . '/' . $filename . '-' . $softwareId
                . $extension;

            // Reading Filesize
            $parts = parse_url($softwareWget);
            $connection = fsockopen($parts['host'], 80, $errno, $errstr, 30);

            if ($connection) {
                $appdata = get_headers($softwareWget, true);
                $length = isset($appdata['Content-Length']) ? filterDigits($appdata['Content-Length']) : NULL;
                $length ? $remote_file_size = $length : $remote_file_size = 0;
                $show_remote_file_size = bytesHuman($remote_file_size);

                if ($remote_file_size < 1) {
                    // Delete software entry
                    execQuery('DELETE FROM web_software WHERE software_id = ?', [$softwareId]);
                    $show_max_remote_filesize = bytesHuman($cfg['APS_MAX_REMOTE_FILESIZE']);
                    setPageMessage(tr('Your remote filesize (%s) is lower than 1 byte. Please check your URL.', $show_remote_file_size), 'error');
                    $upload = 0;
                } elseif ($remote_file_size > $cfg['APS_MAX_REMOTE_FILESIZE']) {
                    // Delete software entry
                    execQuery('DELETE FROM web_software WHERE software_id = ?', [$softwareId]);

                    $show_max_remote_filesize = bytesHuman($cfg['APS_MAX_REMOTE_FILESIZE']);
                    setPageMessage(
                        tr('Max. remote filesize (%s) has been reached. Your remote file is %s', $show_max_remote_filesize, $show_remote_file_size),
                        'error'
                    );
                    $upload = 0;
                } else {
                    $remoteFile = @file_get_contents($softwareWget);

                    if ($remoteFile) {
                        $outputFile = fopen($destDir, 'w+');
                        fwrite($outputFile, $remoteFile);
                        fclose($outputFile);
                    } else {
                        // Delete software entry
                        execQuery('DELETE FROM web_software WHERE software_id = ?', [$softwareId]);
                        setPageMessage(tr('Remote file not found.'), 'error');
                        $upload = 0;
                    }
                }
            } else {
                // Delete software entry
                execQuery('DELETE FROM web_software WHERE software_id = ?', [$softwareId]);
                setPageMessage(tr('Could not upload file.'), 'error');
                $upload = 0;
            }
        }

        if ($upload == 1) {
            $tpl->assign([
                'VAL_WGET'     => '',
                'SW_INSTALLED' => ''
            ]);
            sendDaemonRequest();
            setPageMessage(tr('File successfully uploaded.'), 'success');
        } else {
            $tpl->assign('VAL_WGET', $softwareWget);
        }
    } else {
        $tpl->assign('VAL_WGET', $_POST['sw_wget']);
    }
} else {
    unset($_SESSION['software_upload_token']);
    $tpl->assign('VAL_WGET', '');
}

$sw_cnt = get_avail_software_reseller($tpl, $_SESSION['user_id']);

$tpl->assign([
    'TR_PAGE_TITLE'                 => tr('Reseller / General / Software Upload'),
    'TR_SOFTWARE_UPLOAD'            => tr('Software upload'),
    'GENERAL_INFO'                  => tr('General information'),
    'TR_UPLOADED_SOFTWARE'          => tr('Software available'),
    'TR_SOFTWARE_NAME'              => tr('Software-Synonym'),
    'TR_SOFTWARE_VERSION'           => tr('Software-Version'),
    'TR_SOFTWARE_LANGUAGE'          => tr('Language'),
    'TR_SOFTWARE_STATUS'            => tr('Software status'),
    'TR_SOFTWARE_TYPE'              => tr('Type'),
    'TR_SOFTWARE_DELETE'            => tr('Action'),
    'TR_SOFTWARE_COUNT'             => tr('Software total'),
    'TR_SOFTWARE_NUM'               => $sw_cnt,
    'TR_UPLOAD_SOFTWARE'            => tr('Software upload'),
    'TR_SOFTWARE_DB'                => tr('Requires Database?'),
    'TR_SOFTWARE_DB_PREFIX'         => tr('Database prefix'),
    'TR_SOFTWARE_HOME'              => tr('Link to authors homepage'),
    'TR_SOFTWARE_DESC'              => tr('Description'),
    'SOFTWARE_UPLOAD_TOKEN'         => generateSoftwareUploadToken(),
    'TR_SOFTWARE_FILE'              => tr('Choose file (Max: %1$d MiB)', ini_get('upload_max_filesize')),
    'TR_SOFTWARE_URL'               => tr('or remote file (Max: %s)', bytesHuman($cfg['APS_MAX_REMOTE_FILESIZE'])),
    'TR_UPLOAD_SOFTWARE_BUTTON'     => tr('Upload now'),
    'TR_UPLOAD_SOFTWARE_PAGE_TITLE' => tr('i-MSCP - Sofware Management'),
    'TR_MESSAGE_DELETE'             => tr('Are you sure you want to delete this package?'),
    'TR_MESSAGE_INSTALL'            => tr('Are you sure to install this package from the webdepot?')
]);
generateNavigation($tpl);
generatePageMessage($tpl);
$tpl->parse('LAYOUT_CONTENT', 'page');
Registry::get('iMSCP_Application')->getEventsManager()->dispatch(iMSCP_Events::onResellerScriptEnd, ['templateEngine' => $tpl]);
$tpl->prnt();
unsetMessages();