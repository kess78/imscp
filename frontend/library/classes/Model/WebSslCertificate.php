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

namespace iMSCP\Model;

/**
 * Class WebSslCertificate
 * @package iMSCP\Model
 */
class WebSslCertificate extends BaseModel
{
    /**
     * @var int
     */
    private $webSslCertificateID;

    /**
     * @var int
     */
    private $webDomainID;

    /**
     * @var string
     */
    private $privateKey;

    /**
     * @var string
     */
    private $certificate;

    /**
     * @var string
     */
    private $caBundle;

    /**
     * @var int
     */
    private $hsts = 0;

    /**
     * @var int
     */
    private $hstsMaxAge = 31536000;

    /**
     * @var int
     */
    private $hstsIncludeSubdomains = 0;

    /**
     * @return int
     */
    public function getWebSslCertificateID(): int
    {
        return $this->webSslCertificateID;
    }

    /**
     * @param int $webSslCertificateID
     * @return WebSslCertificate
     */
    public function setWebSslCertificateID(int $webSslCertificateID): WebSslCertificate
    {
        $this->webSslCertificateID = $webSslCertificateID;
        return $this;
    }

    /**
     * @return int
     */
    public function getWebDomainID(): int
    {
        return $this->webDomainID;
    }

    /**
     * @param int $webDomainID
     * @return WebSslCertificate
     */
    public function setWebDomainID(int $webDomainID): WebSslCertificate
    {
        $this->webDomainID = $webDomainID;
        return $this;
    }

    /**
     * @return string
     */
    public function getPrivateKey(): string
    {
        return $this->privateKey;
    }

    /**
     * @param string $privateKey
     * @return WebSslCertificate
     */
    public function setPrivateKey(string $privateKey): WebSslCertificate
    {
        $this->privateKey = $privateKey;
        return $this;
    }

    /**
     * @return string
     */
    public function getCertificate(): string
    {
        return $this->certificate;
    }

    /**
     * @param string $certificate
     * @return WebSslCertificate
     */
    public function setCertificate(string $certificate): WebSslCertificate
    {
        $this->certificate = $certificate;
        return $this;
    }

    /**
     * @return string
     */
    public function getCaBundle(): string
    {
        return $this->caBundle;
    }

    /**
     * @param string $caBundle
     * @return WebSslCertificate
     */
    public function setCaBundle(string $caBundle): WebSslCertificate
    {
        $this->caBundle = $caBundle;
        return $this;
    }

    /**
     * @return int
     */
    public function getHsts(): int
    {
        return $this->hsts;
    }

    /**
     * @param int $hsts
     * @return WebSslCertificate
     */
    public function setHsts(int $hsts): WebSslCertificate
    {
        $this->hsts = $hsts;
        return $this;
    }

    /**
     * @return int
     */
    public function getHstsMaxAge(): int
    {
        return $this->hstsMaxAge;
    }

    /**
     * @param int $hstsMaxAge
     * @return WebSslCertificate
     */
    public function setHstsMaxAge(int $hstsMaxAge): WebSslCertificate
    {
        $this->hstsMaxAge = $hstsMaxAge;
        return $this;
    }

    /**
     * @return int
     */
    public function getHstsIncludeSubdomains(): int
    {
        return $this->hstsIncludeSubdomains;
    }

    /**
     * @param int $hstsIncludeSubdomains
     * @return WebSslCertificate
     */
    public function setHstsIncludeSubdomains(int $hstsIncludeSubdomains): WebSslCertificate
    {
        $this->hstsIncludeSubdomains = $hstsIncludeSubdomains;
        return $this;
    }
}
