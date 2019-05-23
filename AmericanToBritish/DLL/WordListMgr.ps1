[CmdletBinding(DefaultParameterSetName = 'Undefined', PositionalBinding = $false)]
[OutputType([void])]
param (
	[Parameter(ParameterSetName = 'Upkeep', Mandatory = $true)]
	[switch]
	$Upkeep,
	[Parameter(ParameterSetName = 'Strip', Mandatory = $true)]
	[string][ValidateNotNullorEmpty()]
	$Strip
)
$ErrorActionPreference = 'Stop'; $Error.Clear(); $Error.Capacity = 16

if ($PSCmdlet.ParameterSetName -eq 'Strip') {
	$file = Get-Item -LiteralPath $Strip
	$doc = New-Object -Type System.Xml.XmlDocument -Property @{ XmlResolver = $null }
	$doc.Load($file.OpenRead())
	for ($i = $doc.DocumentElement.ChildNodes.Count - 1; $i -ge 0; $i -= 1) {
		$node = $doc.DocumentElement.ChildNodes[$i]
		if ($node.NodeType -ne 'Element' -or $node.Name -cne 'Word') {
			$null = $doc.DocumentElement.RemoveChild($node)
		}
	}
	$doc.Save($file.FullName)
	exit 0
}
if ($PSCmdlet.ParameterSetName -eq 'Upkeep') {
	$engb = Get-Item -LiteralPath WordList_en-GB.xml
	$oed = Get-Item -LiteralPath WordList.xml

	function Get-WordList ($file) {
		$comments = New-Object -Type 'System.Collections.Generic.List[string]'
		$words = New-Object -Type 'System.Collections.Generic.Dictionary[string, string]'
		$doc = New-Object -Type System.Xml.XmlDocument -Property @{ XmlResolver = $null }
		$doc.Load($file.OpenRead())

		for ($node = $doc.DocumentElement.FirstChild; $null -ne $node; $node = $node.NextSibling) {
			if ($node.NodeType -eq 'Element') {
				if (![string]::IsNullOrEmpty($node.InnerText) -or $node.Attributes.Count -ne 2 ) {
					throw "$($file.Name): $($node.OuterXml)"
				}
				if (![string]::IsNullOrWhiteSpace($node.Attributes[0].Value) -or ![string]::IsNullOrWhiteSpace($node.Attributes[1].Value)) {
					$us = $node.Attributes[0].Value.Trim().ToLowerInvariant()
					$br = $node.Attributes[1].Value.Trim().ToLowerInvariant()
					if ($node.Attributes[1].Name -eq 'us' -and $node.Attributes[0].Name -eq 'br') {
						$us, $br = $br, $us
					} elseif ($node.Attributes[0].Name -ne 'us' -or $node.Attributes[1].Name -ne 'br') {
						throw "$($file.Name): Attributes: $($node.OuterXml)"
					}
					if ([string]::IsNullOrEmpty($us)) {
						throw "$($file.Name): empty us: $($node.OuterXml)"
					} elseif ([string]::IsNullOrEmpty($br)) {
						throw "$($file.Name): empty br: $($node.OuterXml)"
					}
					if (!$words.ContainsKey($us)) {
						$words.Add($us, $br)
					} elseif ($words[$us] -ne $br) {
						throw "$($file.Name): duplicate us: $($node.OuterXml)"
					}
				}
			} elseif ($node.NodeType -eq 'Comment') {
				$comments.Add($node.Value.Trim())
			} else {
				throw "$($file.Name): NodeType $($node.NodeType): $($node.OuterXml)"
			}
		}
		[PSCustomObject]@{ Document = $doc; Comments = $comments; Words = $words }
	}

	function Xml-WordList ($o) {
		$doc = $o.Document
		$root = $doc.CreateElement('Words')
		foreach ($c in $o.Comments) {
			$null = $root.AppendChild($doc.CreateComment(" $c "))
		}
		$o.Words.GetEnumerator() | Sort-Object -Culture '' -CaseSensitive -Property Key, Value | ForEach-Object {
			$e = $doc.CreateElement('Word')
			$e.SetAttribute('us', $_.Key)
			$e.SetAttribute('br', $_.Value)
			$null = $root.AppendChild($e)
		}
		$null = $doc.ReplaceChild($root, $doc.DocumentElement)
	}

	$wl = Get-WordList $engb
	Xml-WordList $wl
	$wl.Document.Save($engb.FullName)

	$wl = Get-WordList $oed
	Xml-WordList $wl
	$wl.Document.Save($oed.FullName)

	exit 0
}
exit 1
