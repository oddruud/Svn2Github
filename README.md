Svn2Github
==========

A command line wizard tool to create a github project from any svn repository, retaining the svn history.

Enter your svn and github credentials:  

```javascript
{"svn":{"user":"svn_user", 
		"password":"svn_pwd"
	   },
"github":{	"user":"github_user", 
			"password":"github_pwd", 	 
			"has_wiki": true,
			"has_downloads": true,
			"has_issues":true,
			"organization":""
		}, 
	"local_git_directory": "repos" 	
}
```

Usage: 

```
svn2github [svn repo]  
```