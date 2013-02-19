<script type="text/javascript">
    /*<![CDATA[*/
    $(document).ready(function () {
        $('#preview').click(function (e) {
            var dialog1 = $("<div/>").append($("<iframe scrolling='auto' />").attr("src", "/orderpanel/index.php")).dialog(
                    {
                        hide:'blind',
                        show:'slide',
                        focus:false,
                        width:900,
                        height:520,
                        autoOpen:false,
                        modal:true,
                        title:"{TR_ORDER_PANEL_PREVIEW}",
                        close:function (e, ui) {
                            $(this).remove();
                        },
                        buttons:{ "{TR_CLOSE}":function () {
                            $(this).dialog("close");
                        } }
                    });
            dialog1.dialog('open');
            return false;
        });
    });
    /*]]>*/
</script>
		<div id="dialog" style="float:left;position: relative"></div>
			<form name="orderSettingsFrm" method="post" action="order_settings.php">

				<table class="firstColFixed">
					<tr>
						<th>{TR_IMPLEMENT_INFO}</th>
					</tr>
					<tr>
						<td>{TR_IMPLEMENT_URL}</td>
					</tr>
				</table>
				<table class="firstColFixed">
					<tr>
						<th colspan="2">{TR_ORDER_TEMPLATE}</th>
					</tr>
					<tr>
						<td><label for="orderTemplateHeader">{TR_HEADER}</label></td>
						<td><textarea name="header" id="orderTemplateHeader">{PURCHASE_HEADER}</textarea></td>
					</tr>
					<tr>
						<td><label for="orderTemplateFooter">{TR_FOOTER}</label></td>
						<td><textarea name="footer" id="orderTemplateFooter">{PURCHASE_FOOTER}</textarea></td>
					</tr>
				</table>
				<div class="buttons">
                    <input name="button" type="button" id="preview" value="{TR_PREVIEW}"/>
					<!--<input name="button" type="button" onclick="window.open('/orderpanel/index.php', 'preview', 'width=850,height=480')" value="{TR_PREVIEW}"/>-->
					<input name="update" type="submit" value="{TR_UPDATE}"/>
					<input name="reset" type="submit" value="{TR_RESET}"/>
				</div>
			</form>

