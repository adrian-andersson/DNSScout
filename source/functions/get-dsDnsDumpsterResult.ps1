





function get-dsDnsDumpsterResult
{

    <#
        .SYNOPSIS
            Simple description
            
        .DESCRIPTION
            Detailed Description
            
        ------------
        .EXAMPLE
            verb-noun param1
            
            #### DESCRIPTION
            Line by line of what this example will do
            
            
            #### OUTPUT
            Copy of the output of this line
            
            
            
        .NOTES
            Author: Adrian Andersson
            
            
            Changelog:
            
                yyyy-mm-dd - AA
                    - Changed x for y
                    
    #>

    [CmdletBinding()]
    PARAM(
        #Domain Name
        [Parameter(Mandatory,ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [Alias("domain")]
        [string]$domainName
    )
    begin{
        #Return the script name when running verbose, makes it tidier
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        #Return the sent variables when running debug
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $userAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
        $uri = 'https://dnsdumpster.com'
        $refererUrl = 'https://dnsdumpster.com/'
    }
    
    process{
        

        $wr = Invoke-WebRequest -SessionVariable webSession -uri $uri -UserAgent $userAgent

        $postParams = @{
            csrfmiddlewaretoken = $wr.InputFields.where{$_.name -eq 'csrfmiddlewaretoken'}.value
            targetip = $domainName
            user = 'free'
        }

        
        $webSession.Headers.Add('Referer',$refererUrl)

        $wr2 = Invoke-WebRequest -Uri $uri -Method POST -Body $postParams -WebSession $webSession -UserAgent $userAgent
        $parsedhtml = ConvertFrom-Html $wr2.RawContent

        $body = $parsedHtml.ChildNodes.where{$_.name -eq 'html'}.childNodes.where{$_.name -eq 'Body'}
        $site = $body.ChildNodes.Where{$_.GetClasses() -eq 'site-wrapper'}


        $site.childnodes.where{$_.name -eq 'div'}.childnodes.where{$_.name -eq 'section'}.childNodes


        $tables = $parsedHtml.SelectNodes('//table')
        $paragraphs = $parsedHtml.SelectNodes('//p')
        $resultHash = @{}
        $i = 0
        switch -wildcard ($paragraphs.innertext)  {
            '*DNS Servers*' {
                $tableRef = $i
                #write-warning "DNS at Table Reference: $i"
                $dns = $tables[$i]
                $resultHash.dnsEntrys = $dns.ChildNodes.where{$_.name -eq 'tr'}.foreach{
                    [PSCustomObject]@{
                        'DnsServer' = $_.childnodes[0].innertext
                        'IPAddress' = $_.childnodes[1].innertext
                        'Owner' = $_.childnodes[2].innertext
                    }
                }

                $i++
            }
            '*TXT Records*' {
                $tableRef = $i
                #write-warning "TXT at Table Reference: $i"
                $txt = $tables[$i]
                $resultHash.txtEntries = $txt.ChildNodes.where{$_.name -eq 'tr'}.foreach{
                    $($_.childNodes.innertext).replace('&quot;','')
                }
                $i++
            }
            '*MX Records*' {
                $tableRef = $i
                $mx = $tables[$i]
                $resultHash.mxEntries = $mx.ChildNodes.where{$_.name -eq 'tr'}.foreach{
                    [PSCustomObject]@{
                        'MailServer' = $_.childnodes[0].innertext
                        'IPAddress' = $_.childnodes[1].innertext
                        'Owner' = $_.childnodes[2].innertext
                    }
                }
                #write-warning "MX at Table Reference: $i"
                $i++
            }
            '*Host Records (A)*' {
                $tableRef = $i
                $a = $tables[$i]
                $resultHash.aEntries = $a.ChildNodes.where{$_.name -eq 'tr'}.foreach{
                    [PSCustomObject]@{
                        'dnsName' = $_.childnodes[0].childnodes[0].innertext
                        'IPAddress' = $_.childNodes[1].innertext
                        'Owner' = $_.ChildNodes[2].ForEach{$_.innertext}.trim() -join ','
                    }
                }
                #write-warning "A at Table Reference: $i"
                $i++
            }
        }

        $mapSource = $parsedHtml.SelectNodes('//img').attributes.where{$_.name -eq 'src'}.value.where{$_ -notlike '*know-your-network-tools*'}

        $mapUri = "$($uri)$($mapSource)"

        [PSCustomObject]$resultHash
        
    }
    
}