<?xml version="1.0"?>
<!DOCTYPE xsl:stylesheet [ <!ENTITY nbsp "&#160;"> ]>


<!--

    This template processes a testcase report xml and creates a testcase summary file as well as
    detailed testcase report html.

-->


<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:stringutils="xalan://org.apache.tools.ant.util.StringUtils" xmlns:redirect="http://xml.apache.org/xalan/redirect" extension-element-prefixes="redirect">
    <!-- <xsl:output method="html" indent="yes" encoding="US-ASCII" doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN" /> -->
    <xsl:output method="html" indent="yes" encoding="US-ASCII" />



<xsl:template match="panopage">

    <html><head><title>Redirect to thumbnails page</title><meta http-equiv="Refresh" content="0; URL=html/preview-250.html"/></head></html>

    
    <xsl:for-each select="./sizes/size">
	<xsl:call-template name="mkprevpage">
	    <xsl:with-param name="size" select="."/>
	    <xsl:with-param name="filename">html/preview-<xsl:value-of select="."/>.html</xsl:with-param>
	</xsl:call-template>
    </xsl:for-each>


</xsl:template>



<xsl:template name="mkprevpage">
    <xsl:param name="size" select="1280"/>
    <xsl:param name="filename" select="html/default"/>
    
    <redirect:write file="{$filename}">
	<html><head><title><xsl:value-of select="$size"/></title>
	    <xsl:call-template name="css"/>
	</head><body>
	
	    <div style="text-align: right; border-bottom: 1px solid grey; padding: 4px;">Preview image size: 
		<xsl:for-each select="/panopage/sizes/size">
		    <xsl:if test="position() > 1">
			|
		    </xsl:if>
		    <a><xsl:attribute name="href">preview-<xsl:value-of select="."/>.html</xsl:attribute><xsl:value-of select="."/>px</a>
		</xsl:for-each>
	    </div>
	
	    <center><table border="0" cellspacing="0" cellpadding="2px">
	
		<xsl:for-each select="/panopage/images/image[ panosource != 'true' and panoworkfile != 'true' and nti != 'true' ]">
		    <xsl:sort select="exif/DateTime"/>
		    <xsl:sort select="original"/>
		    <tr>
			<td>
			    <xsl:if test="position() > 1"><xsl:attribute name="style">border-top: 1px solid black;</xsl:attribute></xsl:if>
			    <xsl:value-of select="position()"/>
			</td>
		        <td rowspan="1">
			    <xsl:if test="position() > 1"><xsl:attribute name="style">border-top: 1px solid black;</xsl:attribute></xsl:if>
		            <center><img>
				<xsl:attribute name="src"> ../<xsl:value-of select="./thumbnail[ @size = $size ]/file"/></xsl:attribute>
			    </img></center>
		        </td>
			<td>
			    <xsl:if test="position() > 1"><xsl:attribute name="style">border-top: 1px solid black;</xsl:attribute></xsl:if>
			    <table border="0">
				<tr>
				    <td>    
					Original&nbsp;file: 
				    </td>
				    <td colspan="3">    
					<b><a><xsl:attribute name="href">../<xsl:value-of select="./original"/></xsl:attribute><xsl:value-of select="./original"/></a></b>
				    </td>
				    
				</tr>
				
				<xsl:if test="exif">
				    <tr><td>DateTime</td><td colspan="3"><b><xsl:value-of select="exif/DateTime"/></b></td></tr>
				    <tr><td>Make, model</td><td colspan="3"><b><xsl:value-of select="exif/Make"/>, <xsl:value-of select="exif/Model"/></b></td></tr>
					
				</xsl:if>
				
				<tr>
				    <td>
					File&nbsp;size:
				    </td>
				    <td style="text-align: right;">
					<b><xsl:value-of select="format-number(./size div 1000000,'0.0')"/></b>
				    </td>
				    <td>
					MiB
				    </td>
				    <td width="100%"> </td>
				</tr>
				<tr>
				    <td>
					Image&nbsp;width:
				    </td>
				    <td style="text-align: right;">
					<b><xsl:value-of select="./width"/></b>
				    </td>
				    <td>
				        px
				    </td>
				</tr>
				<tr>
				    <td>
					Image&nbsp;height:
				    </td>
				    <td style="text-align: right;">
					<b><xsl:value-of select="./height"/></b>
				    </td>
				    <td>
				        px
				    </td>
				</tr>
				<tr>
				    <td>
					Image&nbsp;size:
				    </td>
				    <td style="text-align: right;">
					<b><xsl:value-of select="format-number(./width * ./height div 1000000,'0.0')"/></b>
				    </td>
				    <td>
					MPixel
		    		    </td>
		    		</tr>
				<tr>
				    <td>
					Your opinion:
				    </td>
				    <td colspan="3">
					<a><xsl:attribute name="href">mailto:gimre@chemaxon.com?subject=MUSTHAVE: <xsl:value-of select="original"/></xsl:attribute>Must have</a> | 
					<a><xsl:attribute name="href">mailto:gimre@chemaxon.com?subject=MAYBE: <xsl:value-of select="original"/></xsl:attribute>Maybe</a> | 
					<a><xsl:attribute name="href">mailto:gimre@chemaxon.com?subject=SUCKS: <xsl:value-of select="original"/></xsl:attribute>This sucks</a>  
				    </td>
				</tr>
				<tr>
				    <td>
				        Preview
				    </td>
				    <td colspan="3">
					<xsl:for-each select="./thumbnail">
					    <xsl:if test="position() > 1">
						|
					    </xsl:if>
					    <a target="_blank">
						<xsl:attribute name="href">../<xsl:value-of select="file"/></xsl:attribute>
						<xsl:value-of select="@size"/>
					    </a>
					</xsl:for-each>
				    </td>
				</tr>
			    </table>
			</td>
		    </tr>
			
		</xsl:for-each>
	
	    </table></center>
	
	
	</body></html>	
        
    </redirect:write>

</xsl:template>


    

<!-- template for embedded css ########################################################################### -->
<xsl:template name="css">
        <style type="text/css">
            body { font:normal 68% verdana,arial,helvetica; color:#000000; margin: 0px;}
            table tr td, table tr th { font-size: 68%; }
            table.details tr th { font-weight: bold; text-align:left; background:#a6caf0; }
            table.details tr td { background:#eeeee0; }
            p { line-height:1.5em; margin-top:0.5em; margin-bottom:1.0em; }
            h1 { margin: 0px 0px 5px; font: 165% verdana,arial,helvetica }
            h2 { margin-top: 1em; margin-bottom: 0.5em; font: bold 125% verdana,arial,helvetica }
            h3 { margin-bottom: 0.5em; font: bold 115% verdana,arial,helvetica }
            h4 { margin-bottom: 0.5em; font: bold 100% verdana,arial,helvetica }
            h5 { margin-bottom: 0.5em; font: bold 100% verdana,arial,helvetica }
            h6 { margin-bottom: 0.5em; font: bold 100% verdana,arial,helvetica }
            .Error { font-weight:bold; color:red; }
            .Failure { font-weight:bold; color:purple; }
            .Properties { text-align:right; }
	        .Outlinks { text-align:left; }
	        .Out { font-weight:normal; color: black; margin-top:0em; margin-bottom:0em; }
        </style>
</xsl:template>

<!-- File names  ######################################################################################### -->


<!-- Write files ######################################################################################### -->


</xsl:stylesheet>
							   