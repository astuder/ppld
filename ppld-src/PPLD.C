#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <alloc.h>
#include <io.h>

typedef unsigned char byte;
typedef unsigned int word;
typedef unsigned long ulong;

#include "names.inc"
#include "types.inc"

#define PPLDVER "3.20"
#define LastFunc 0xfee2
#define LastStat 0x00e2
#define LastPPLC 330

void	SymInit(void);
void	SymLine(word);
void	SymVar(int);
void	SymFunc(word,int);
void	SymWrite(void);
void    UsageError(void);
void	initstack(void);
void	pushstr(char*);
char*	popstr(void);
char*   popstrip(void);

char*	stripper(char*);
void    BigLetter(char*);

void	labelin(word);
int		labelnr(word);
void	labelout(word);

void	funcin(word,int);
void    funcout(word);

int		fnktout(word);
char*	varout(word);

char*	ConstName(long*,char*[]);
char*	TransExp(int);

int     dimexpr(int);
int     getexpr(int,int);

word    ReadSource(void);
void    ReadVars(int);
void    InitDecomp(void);
int     DoPass1(word);
int     DoPass2(word);
void    DumpVars(int);
void	DumpLocs(int);
void    DumpStats(void);
void    DumpFuncs(void);
void	outputFunc(int);
void	outputProc(int);
void	DeCode(byte*,word);
void    DeCode2(byte*,byte*,word,word);

char 	SrcName[128],DstName[128];
byte    Buff[64];

typedef struct {
	int  Type;
	byte Dim;
	int  Dims[3];
	ulong Content;
	ulong Content2;
	char *StrPtr;
	char Flag,LFlag,FFlag;
	int  Number;
	char Args,TotalVar;
	word Start;
	int  FirstVar;
	int  ReturnVar;
	int  Func;
	} PPEVar;

typedef struct {
	word Label;
	int  Func;
	} FuncL;

PPEVar  *VarDefs;
word	*SrcBuff, *ValidBuff;

char 	TempStr[10000],TempStr2[10000];
int		StackPtr, StackSize;
char	*Stack;

word	SrcPtr;
int		AktStat,AktProc,UVarFlag=0,Pass=0,PassWheel=0;
int		Trace=1,Symbol=0;

word	StatUsed[256],FnktUsed[512];
word 	LabelUsed[1000];
FuncL   FuncUsed[1000];
int		NextLabel,NextFunc;
int		FuncFlag,ProcFlag;

word    LabelStack[1000];
int     LabelStackPtr=0;
long	MemLeft;

FILE 	*SrcFile,*DstFile;
int 	version,maxVar;
int		ExpCount,TrashFlag,TrashFlag2;
double  floatDummy;

typedef struct {
	char magic[3];
	byte revision;
	long filesize;
	long srcstart;
	long srctable;
	long vartable;
	long functable;
	} SymHeader_t;

SymHeader_t SymHeader;

typedef struct {
	word LNumber;
	long FOffset;
	} lindex_t;
lindex_t	*LineIndex;
int			LineCount=0;

typedef struct {
	int vnumber;
	int vfunc;
	char vname[28];
	} vindex_t;
vindex_t	*VarIndex;
int			VICount=0;

typedef struct {
	int fnumber;
	int foffset;
	} findex_t;
findex_t	*FuncIndex;
int			FICount=0;

int main(int argc, char *argv[])
{
	word    CodeSize;
	int     i,j,k,l;

	floatDummy=1.5*3.543221; //TO GET THE FLOATINGPOINT-LIBS LINKED!!!

	printf("\nPPLD Version " PPLDVER " - PCBoard Programming Language Decompiler");
	printf("\nCopyright (C)1994-97, Chicken / Tools4Fools\n");

	if (argc<2) UsageError();

	k=1; l=0;
	while (k<argc)
	{
		if (argv[k][0]=='/')
		{
			if(strcmpi(argv[k],"/NOTRACE")==0) Trace=0;
			else if(strcmpi(argv[k],"/SYMBOLIC")==0) Symbol=1;
			else UsageError();
		}
		else if (l==0)
		{
			strcpy(SrcName,argv[k]);
			l++;
		}
		else if (l==1)
		{
			strcpy(DstName,argv[k]);
			l++;
		}
		else UsageError();

		k++;
	}

	i=strlen(SrcName);
	if ((SrcName[i-1]!='.')&&(SrcName[i-2]!='.')&&
		(SrcName[i-3]!='.')&&(SrcName[i-4]!='.')) strcat(SrcName,".ppe");
	BigLetter(SrcName);

	if ((SrcFile=fopen(SrcName,"rb"))==NULL)
	{
		printf("\nError: %s not found on disk, aborting...\n",SrcName);
		exit(1);
	}

	if (l==1)
	{
		strcpy(DstName,SrcName);
		i=strlen(DstName); j=i-5;
		while ((i>j)&&(DstName[i]!='.')) i--;
		if (DstName[i]=='.') DstName[i]=0;
	}

	i=strlen(DstName);
	if ((DstName[i-1]!='.')&&(DstName[i-2]!='.')&&
		(DstName[i-3]!='.')&&(DstName[i-4]!='.'))
		{
			if (Symbol==0) strcat(DstName,".ppd");
			else strcat(DstName,".sym");
		}

	BigLetter(DstName);

	if (Symbol==0)
	{
		if ((DstFile=fopen(DstName,"w+"))==NULL)
		{
			printf("\nError: Can't create %s on disk, aborting...\n",DstName);
			exit(1);
		}
	}
	else
	{
		if ((DstFile=fopen(DstName,"w+b"))==NULL)
		{
			printf("\nError: Can't create %s on disk, aborting...\n",DstName);
			exit(1);
		}
	}


	if (Symbol==0)
	{
		fprintf(DstFile,";------------------------------------------------------------------------------\n");
		fprintf(DstFile,";PCBoard Programming Language Decompiler " PPLDVER "  (C)1994-96 Chicken / Tools4Fools\n");
		fprintf(DstFile,";------------------------------------------------------------------------------\n");
		fprintf(DstFile,";\n");
	}
	else fwrite(&SymHeader,sizeof(SymHeader_t),1,DstFile);

	if (Symbol==1) SymInit();
	InitDecomp();
	CodeSize=ReadSource();

	printf("\nPass 1 ... /");
	if (DoPass1(CodeSize)) exit(1);
	printf("\b \n");
	Pass++;

	DumpVars(maxVar);

	printf("\nPass 2 ... /");
	if (DoPass2(CodeSize)) exit(1);
	printf("\b \n");

	printf("\nSource decompilation complete...\n");

	if (Symbol==0)
	{
		fprintf(DstFile,"\n;------------------------------------------------------------------------------");
		DumpStats();
		DumpFuncs();
	}

	if (TrashFlag2!=0)
	{
		if (Symbol==0)
		{
		fprintf(DstFile,";\n;------------------------------------------------------------------------------\n");
		fprintf(DstFile,";\n;!!! %d ERROR(S) CAUSED BY PPLC BUGS DETECTED\n;\n",TrashFlag2);
		fprintf(DstFile,";PROBLEM: These expressions most probably looked like !0+!0+!0 or similar\n");
		fprintf(DstFile,";         before PPLC fucked it up to something like !(!(+0)+0)!0. This may\n");
		fprintf(DstFile,";         also apply to - / and * aswell. Also occurs upon use of multiple !'s.\n");
		fprintf(DstFile,";         Some smartbrains use this BUG to make programms running different\n");
		fprintf(DstFile,";         (or not at all) when being de- and recompiled.\n");
		}
		printf("\n%d COMPILER ERROR(S) DETECTED\n",TrashFlag2);
	}

	if (Symbol==0)
	{
		fprintf(DstFile,";\n;------------------------------------------------------------------------------\n");
		fprintf(DstFile,";Thank you for using PPLD              T4F - We Create Your Needs Of Tommorow !\n");
		fprintf(DstFile,";------------------------------------------------------------------------------\n");
	}
	else SymWrite();

	fcloseall();
	return 0;
}

void UsageError (void)
{
	printf("\nUSAGE: PPLD [OPTIONS] SRCNAME[.EXT] [DSTNAME[.EXT]]\n");
	printf("\n NOTE: .EXT defaults to .PPE and .PPD if not specified\n");
	printf("\nOptions:\n");
	printf("\n/NOTRACE - Disable Trace Mode\n");
	printf("\n/SYMBOLIC - Create Symbolic File (For PPLDebug)\n");
	exit(1);
}

/* FUNCTIONS */

// collect/output symbolic infos

void SymInit(void)
{
	if ((LineIndex=malloc(10000*sizeof(lindex_t)))==NULL)
	{
		printf("\nError: Not enough RAM, aborting...\n"); exit(1);
	}
	if ((VarIndex=malloc(10000*sizeof(vindex_t)))==NULL)
	{
		printf("\nError: Not enough RAM, aborting...\n"); exit(1);
	}
	if ((FuncIndex=malloc(10000*sizeof(findex_t)))==NULL)
	{
		printf("\nError: Not enough RAM, aborting...\n"); exit(1);
	}

	SymHeader.magic[0]='S';
	SymHeader.magic[1]='Y';
	SymHeader.magic[2]='M';
	SymHeader.revision=1;
}

void SymLine(word LineNr)
{
	if (LineCount>=10000)
	{
		printf("\nError: Too many lines...\n"); exit(1);
	}
	LineIndex[LineCount].LNumber=LineNr;
	fgetpos(DstFile,&LineIndex[LineCount].FOffset);
	LineIndex[LineCount].FOffset-=sizeof(SymHeader);
	LineCount++;
}

void SymVar(int i)
{
	int j;
	if (VICount>=10000)
	{
		printf("\nError: Too many vars...\n"); exit(1);
	}
	VarIndex[VICount].vnumber=i+1;
	VarIndex[VICount].vfunc=0;
	if (VarDefs[i].Func!=0) VarIndex[VICount].vfunc=VarDefs[i].Func+1;
	for(j=0;j<28;j++) VarIndex[VICount].vname[j]=0;
	strcpy(VarIndex[VICount].vname,varout(i+1));
	VICount++;
}

void SymFunc(word LineNr, int i)
{
	if (FICount>=10000)
	{
		printf("\nError: Too many functions/procedures...\n"); exit(1);
	}
	FuncIndex[FICount].foffset=LineNr;
	FuncIndex[FICount].fnumber=i+1;
	FICount++;
}

void SymWrite(void)
{
	int j;

	LineIndex[LineCount].LNumber=-1;
	LineIndex[LineCount].FOffset=0;
	LineCount++;

	if (UVarFlag==1) for(j=0;j<=22;j++) SymVar(j);
	if ((UVarFlag==1)&&(version>=300)) SymVar(23);

	VarIndex[VICount].vnumber=-1;
	VarIndex[VICount].vfunc=0;
	for(j=0;j<28;j++) VarIndex[VICount].vname[j]=0;
	VICount++;

	FuncIndex[FICount].fnumber=-1;
	FuncIndex[FICount].foffset=0;
	FICount++;

	SymHeader.srcstart=sizeof(SymHeader_t);
	fgetpos(DstFile,&SymHeader.srctable);
	fwrite(LineIndex,sizeof(lindex_t),LineCount,DstFile);
	fgetpos(DstFile,&SymHeader.vartable);
	fwrite(VarIndex,sizeof(vindex_t),VICount,DstFile);
	fgetpos(DstFile,&SymHeader.functable);
	fwrite(FuncIndex,sizeof(findex_t),FICount,DstFile);
	fgetpos(DstFile,&SymHeader.filesize);
	fseek(DstFile,0,0);
	fwrite(&SymHeader,sizeof(SymHeader_t),1,DstFile);
}

// init string-stack

void initstack(void)
{
	StackPtr=0; StackSize=10000;
	if ((Stack=malloc(StackSize))==NULL)
	{
		printf("\nError: Not enough RAM, aborting...\n"); exit(1);
	}
}

// push string on stack

void pushstr(char *String)
{
	int Len;

	ExpCount++;
	Len=(strlen(String)+1);
	if (StackPtr+Len+2>StackSize)
	{
		StackSize+=10000;
		if ((Stack=realloc(Stack,StackSize))==NULL)
		{
			printf("\nError: Not enough RAM, aborting...\n"); exit(1);
		}
	}
	strcpy(&Stack[StackPtr],String);
	StackPtr+=Len;
	Stack[StackPtr]=Len&0xff;
	Stack[StackPtr+1]=Len/256;
	StackPtr+=2;
}

// pop string from stack

char* popstr(void)
{
	if (StackPtr==0) return("");
	ExpCount--;
	StackPtr-=(((byte)Stack[StackPtr-1])*256+(byte)Stack[StackPtr-2]+2);
	return(&Stack[StackPtr]);
}

// pop string and strip brackets

char* popstrip(void)
{
	return stripper(popstr());
}

// strip brackets out of string

char* stripper(char* String)
{
	int		brackets[200];
	int		Akt=0,AktBr=0,Last,InStr=0;

	strcpy(TempStr,String);
	Last=strlen(TempStr);

	while (Akt<Last)
	{
		switch (TempStr[Akt]) {
		 case '"': InStr^=1; break;
		 case '(': if (InStr!=1) brackets[AktBr++]=Akt; break;
		 case ')': if (InStr!=1)
				   {
					AktBr--;
					if (((AktBr==0)&&(brackets[AktBr]==0)&&(Akt==Last-1))||
						((AktBr!=0)&&(brackets[AktBr]==brackets[AktBr-1]+1)
						  &&((TempStr[Akt+1]==')')||
							 (TempStr[Akt+1]=='+')||
							 (TempStr[Akt+1]=='-'))))
					{
							strncpy(TempStr2,TempStr,brackets[AktBr]);
							TempStr2[brackets[AktBr]]=0;
							strncat(TempStr2,&TempStr[brackets[AktBr]+1],
								   (Akt-brackets[AktBr]-1));
							TempStr2[Akt-1]=0;
							strcat(TempStr2,&TempStr[Akt+1]);
							TempStr2[Last-2]=0;
							strcpy(TempStr,TempStr2);
							Akt-=2;	Last-=2;
					}
				  }
				  break;
		 default: break;
		}
		Akt++;
	}

	return TempStr;
}

void BigLetter(char* String)
{
	int i=-1;
	while (String[++i]!=0) String[i]=toupper(String[i]);
}

// add function to function-list

void funcin(word Label, int Func)
{
	int i=0;
	word Tmp;
	int Tmp2;

	while (FuncUsed[i].Label<Label) i++;
	if (FuncUsed[i].Label!=Label)
	{
		while (FuncUsed[i].Label>Label)
		{	Tmp=FuncUsed[i].Label;
			FuncUsed[i].Label=Label;
			Label=Tmp;

			Tmp2=FuncUsed[i].Func;
			FuncUsed[i].Func=Func;
			Func=Tmp2;
			i++;
		}
	}
}

// output functionheader if one starts at this line

void funcout(word Label)
{
	while (FuncUsed[NextFunc].Label<Label) NextFunc++;
	if (FuncUsed[NextFunc].Label==Label)
	{
		if (FuncFlag==1)
		{
			if (Symbol==1) SymLine(Label);
			fprintf(DstFile,"    ENDFUNC\n\n");
		}
		if (ProcFlag==1)
		{
			if (Symbol==1) SymLine(Label);
			fprintf(DstFile,"    ENDPROC\n\n");
		}
		FuncFlag=0; ProcFlag=0;

		if (Symbol==1) SymLine(Label);
		fprintf(DstFile,"\n");

		if (VarDefs[FuncUsed[NextFunc].Func].Type==15)
		{
			if (Symbol==1) SymLine(Label);
			outputFunc(FuncUsed[NextFunc].Func);
			FuncFlag=1;
		}
		else
		{
			if (Symbol==1) SymLine(Label);
			outputProc(FuncUsed[NextFunc].Func);
			ProcFlag=1;
		}

		if (Symbol==1) SymLine(Label);

		fprintf(DstFile,"\n");

		DumpLocs(FuncUsed[NextFunc].Func);
		if (Symbol==0) fprintf(DstFile,"\n");
	}
}

// add label to label-list

void labelin(word Label)
{
	int i=0;
	word Tmp;

	while (LabelUsed[i]<Label) i++;
	if (LabelUsed[i]!=Label)
	{
		while (LabelUsed[i]>Label)
		{	Tmp=LabelUsed[i];
			LabelUsed[i]=Label;
			Label=Tmp;
			i++;
		}
	}
}

// get number of label

int labelnr(word Label)
{
	int i=0;

	while (LabelUsed[i]<Label) i++;
	if (LabelUsed[i]!=Label) return(-1);
	return(i);
}

// output label if a goto/gosub points at this line

void labelout(word Label)
{
	while (LabelUsed[NextLabel]<Label) NextLabel++;
	if (LabelUsed[NextLabel]==Label)
	{
		if (Symbol==1) SymLine(Label);
		fprintf(DstFile,"\n");
		if (Symbol==1) SymLine(Label);
		fprintf(DstFile,":LABEL%03d\n",NextLabel);
	}
}

// returns 1 if the position is a label

int labelhere(word Label)
{
	while (LabelUsed[NextLabel]<Label) NextLabel++;
	if (LabelUsed[NextLabel]==Label) return(1);
	return(0);
}

// push+pop label to/from stack

void pushlabel(int Label)
{
	LabelStack[LabelStackPtr++]=Label;
}

word poplabel (void)
{
	LabelStackPtr--;
	if (LabelStackPtr<0) return(-2);
	return(LabelStack[LabelStackPtr]);
}

// convert function to string and put on stack

int fnktout(word Funct)
{
	int i=0;

	switch (FnktVars[Funct]) {
	 case 0x10: if (ExpCount<1) return(-1);
				strcpy(TempStr,"("); strcat(TempStr,FnktNames[Funct]);
				strcat(TempStr,popstr()); strcat(TempStr,")"); break;
	 case 0x11: if (ExpCount<2) return(-1);
				strcpy(TempStr,"(");
				strcpy(TempStr2,popstr()); strcat(TempStr,popstr());
				strcat(TempStr,FnktNames[Funct]);
				strcat(TempStr,TempStr2); strcat(TempStr,")");
				break;
	 default  : if (ExpCount<FnktVars[Funct]) return(-1);
				strcpy(TempStr2,")");
				while (FnktVars[Funct]>i++)
				{
					strcpy(TempStr,popstr());
					if (i!=1) strcat(TempStr,",");
					strcat(TempStr,TempStr2); strcpy(TempStr2,TempStr);
				}
				strcpy(TempStr,FnktNames[Funct]); strcat(TempStr,"(");
				strcat(TempStr,TempStr2); break;
	}
	pushstr(TempStr);
	return(0);
}

// convert variable/constant to string and put on stack

char* varout(word VarNr)
{
	int	i=0,j=0;
//	char TempStr[1000]; char TempStr2[1000];

	VarNr--;
	if (((version<300)&&(VarNr<0x17)&&(UVarFlag==1))||((version>=300)&&(VarNr<0x18)&&(UVarFlag==1)))
	{
		strcpy(TempStr,PrDfNames[VarNr+1]);
	}
	else
	{
		if (VarDefs[VarNr].Flag==1)
		{
			switch (VarDefs[VarNr].Type) {
			 case 15: sprintf(TempStr,"FUNC%03d",VarDefs[VarNr].Number); break;
			 case 16: sprintf(TempStr,"PROC%03d",VarDefs[VarNr].Number); break;
			 default: if (VarDefs[VarNr].FFlag==1) sprintf(TempStr,"FUNC%03d",VarDefs[VarNr].Number);
				 else if (VarDefs[VarNr].LFlag==1) sprintf(TempStr,"LOC%03d",VarDefs[VarNr].Number);
				 else sprintf(TempStr,"VAR%03d",VarDefs[VarNr].Number);
			}
		}
		else
		{
			switch (VarDefs[VarNr].Type) {
			 case  0: if (VarDefs[VarNr].Content!=0) sprintf(TempStr,"TRUE");
					  else sprintf(TempStr,"FALSE"); break;
			 case  2: sprintf(TempStr,"%li",(long) VarDefs[VarNr].Content); break;
			 case  5: sprintf(TempStr,"$%d",(long) VarDefs[VarNr].Content/10); break;
			 case  7: while ((VarDefs[VarNr].StrPtr)[i]!=0)
					  {
						TempStr2[j]=(VarDefs[VarNr].StrPtr)[i];
						if (TempStr2[j]=='"') TempStr2[++j]='"';
						i++; j++;
					  }
					  TempStr2[j]=0;
					  sprintf(TempStr,"%c%s%c",'"',TempStr2,'"'); break;
			 case  8: sprintf(TempStr,"%u",(long) VarDefs[VarNr].Content); break;
			 case 14: sprintf(TempStr,"%lg",*(double*) &VarDefs[VarNr].Content); break;
			 default: sprintf(TempStr,"%li",(long) VarDefs[VarNr].Content); break;

			}
		}
	}
	return TempStr;
}

// convert constant on stack to names if possible and push back

char* ConstName(long *CVars, char *CNames[])
{
	char	*endptr;
	long 	Val;
	int		i=0;

	strcpy(TempStr,popstrip());
	Val=strtol(TempStr,&endptr,10);
	if (endptr==TempStr+strlen(TempStr))
	{
		while ((CVars[i]!=-1)&&(CVars[i]!=Val)) i++;
		if (CVars[i]!=-1) strcpy(TempStr,CNames[i]);
	}
	return(TempStr);
}

// ready expression on stack for output (strip brackets, translate consts)

char* TransExp(int AktExp)
{
			switch(AktStat) {
			 case 0x00c: if (AktExp!=2) return(popstrip());
						 else return(ConstName(PrCFVars,PrCFNames));
			 case 0x00d: if (AktExp!=2) return(popstrip());
						 else return(ConstName(PrCFVars,PrCFNames));
			 case 0x00e: if (AktExp!=2) return(popstrip());
						 else return(ConstName(PrDFVars,PrDFNames));
			 case 0x010: if (AktExp==3) return(ConstName(PrFOVars,PrFONames));
						 else if (AktExp==4)
							  return(ConstName(PrFSVars,PrFSNames));
						 else return(popstrip());
			 case 0x011: if (AktExp==3) return(ConstName(PrFOVars,PrFONames));
						 else if (AktExp==4)
							  return(ConstName(PrFSVars,PrFSNames));
						 else return(popstrip());
			 case 0x012: if (AktExp==3) return(ConstName(PrFOVars,PrFONames));
						 else if (AktExp==4)
							  return(ConstName(PrFSVars,PrFSNames));
						 else return(popstrip());
			 case 0x018: return(ConstName(PrSDVars,PrSDNames));
			 case 0x022: if (AktExp!=6) return(popstrip());
						 else return(ConstName(PrISVars,PrISNames));
			 case 0x02b: if (AktExp!=5) return(popstrip());
						 else return(ConstName(PrISVars,PrISNames));
			 case 0x039: if (AktExp!=2) return(popstrip());
						 else return(ConstName(PrISVars,PrISNames));
			 case 0x070: if (AktExp!=3) return(popstrip());
						 else return(ConstName(PrFPVars,PrFPNames));
			 case 0x0cd:
			 case 0x0ce: if (AktExp!=1) return(popstrip());
						 else return(ConstName(PrACVars,PrACNames));
			default	   : return(popstrip());
			}
}

// process expressions in array indices (recursive)

int dimexpr(int Dims)
{
	int AktDim;
	word TrashFunc;
	int ExpTemp;

	ExpTemp=ExpCount;
	AktDim=0;

	if (Pass==1)
	{
		strcpy(TempStr,popstr());
		strcat(TempStr,"(");
		pushstr(TempStr);
	}

	while (Dims!=AktDim++)
	{
		ExpCount=0; TrashFunc=0;
		SrcPtr++;

		if ((AktDim!=1)&&(Pass==1))
		{
			strcpy(TempStr,popstr());
			strcat(TempStr,",");
			pushstr(TempStr);
		}

		while (SrcBuff[SrcPtr]!=0)
		{
			if (SrcBuff[SrcPtr]<=maxVar)
			{
				if (VarDefs[SrcBuff[SrcPtr]-1].Type==15)
				{
					pushlabel(VarDefs[SrcBuff[SrcPtr]-1].Start);
					VarDefs[SrcBuff[SrcPtr]-1].Flag=1;
					funcin(VarDefs[SrcBuff[SrcPtr]-1].Start,SrcBuff[SrcPtr]-1);
					if (Pass==1)
					{
						strcpy(TempStr2,varout(SrcBuff[SrcPtr]));
						strcpy(TempStr,popstr());
						strcat(TempStr,TempStr2);
						strcat(TempStr,"(");
						pushstr(TempStr);
					}
					SrcPtr++;
					if (getexpr(VarDefs[SrcBuff[SrcPtr-1]-1].Args,1)) return(1);
					SrcPtr--;
					if (Pass==1)
					{
						strcpy(TempStr,popstr());
						strcat(TempStr,")");
						pushstr(TempStr);
					}
				}
				else
				{
					if (Pass==1) pushstr(varout(SrcBuff[SrcPtr]));
					if (SrcBuff[++SrcPtr]!=0)
					{
						VarDefs[SrcBuff[SrcPtr-1]-1].Flag=1;
						if (dimexpr(SrcBuff[SrcPtr])) return(1);
					}
				}
			}
			else
			{
				if ((SrcBuff[SrcPtr]<LastFunc)||(FnktVars[-SrcBuff[SrcPtr]-1]==0xaa))
				{
					printf("\nError: Unknown function %04x, ",SrcBuff[SrcPtr]);
					if ((Pass==1)||(Trace==0)) printf("aborting...\n");
					else printf("avoiding...\n");
					return(1);
				}

				if (Pass==1)
				{
					FnktUsed[-SrcBuff[SrcPtr]-1]++;
					if (fnktout(-SrcBuff[SrcPtr]-1)!=0)
					{
						TrashFunc=SrcBuff[SrcPtr];
						TrashFlag=1;
					}
					else if ((TrashFunc!=0)&&(fnktout(-TrashFunc-1)==0)) TrashFunc=0;
				}
			}
			SrcPtr++;
		}

		if (Pass==1)
		{
			strcpy(TempStr2,popstr());
			strcpy(TempStr,popstr());
			strcat(TempStr,TempStr2);
			pushstr(TempStr);
		}
	}

	if (Pass==1)
	{
		strcpy(TempStr,popstr());
		strcat(TempStr,")");
		pushstr(TempStr);
	}

	ExpCount=ExpTemp;
	return(0);
}

// process expression(s) till end of statement

int getexpr(int MaxExp,int rec)
{
	int	AktExp=0;
	int i;
	int ExpTemp;
	word TrashFunc;

	ExpTemp=ExpCount;
	SrcPtr++;
	while ((MaxExp&0x0ff)!=AktExp++)
	{
		ExpCount=0; TrashFunc=0;
		if ((AktExp!=1)&&(Pass==1))
		{
			strcpy(TempStr,popstr());
			if ((AktStat==8)&&(rec==0)) strcat(TempStr,"=");
			else strcat(TempStr,",");
			pushstr(TempStr);
		}

		while (SrcBuff[SrcPtr]!=0)
		{
			if (SrcBuff[SrcPtr]<=maxVar)
			{
				if ((MaxExp/256==AktExp)||(MaxExp/256==0x0f))
				{
						VarDefs[SrcBuff[SrcPtr]-1].Flag=1;
						if (Pass==1) pushstr(varout(SrcBuff[SrcPtr]));
						if (SrcBuff[++SrcPtr]!=0)
						{
							if (dimexpr(SrcBuff[SrcPtr])) return(1);
							if (Pass==1)
							{
								strcpy(TempStr2,popstr());
								strcpy(TempStr,popstr());
								strcat(TempStr,TempStr2);
								pushstr(TempStr);
							}
						}
				}
				else
				{
					if (AktStat==0xa8)
					{
						if ((VarDefs[AktProc].ReturnVar>>(AktExp-1))&1)
						{
							VarDefs[SrcBuff[SrcPtr]-1].Flag=1;
						}
					}
					if (VarDefs[SrcBuff[SrcPtr]-1].Type==15)
					{
						pushlabel(VarDefs[SrcBuff[SrcPtr]-1].Start);
						VarDefs[SrcBuff[SrcPtr]-1].Flag=1;
						funcin(VarDefs[SrcBuff[SrcPtr]-1].Start,SrcBuff[SrcPtr]-1);
						if (Pass==1)
						{
							strcpy(TempStr2,varout(SrcBuff[SrcPtr]));
							strcpy(TempStr,popstr());
							strcat(TempStr,TempStr2);
							strcat(TempStr,"(");
							pushstr(TempStr);
						}
						SrcPtr++;
						if (getexpr(VarDefs[SrcBuff[SrcPtr-1]-1].Args,1)) return(1);
						if (Pass==1)
						{
							strcpy(TempStr,popstr());
							strcat(TempStr,")");
							pushstr(TempStr);
						}
					}
					else
					{
						if (Pass==1) pushstr(varout(SrcBuff[SrcPtr]));
						if (SrcBuff[++SrcPtr]!=0)
						{
							VarDefs[SrcBuff[SrcPtr-1]-1].Flag=1;
							if (dimexpr(SrcBuff[SrcPtr])) return(1);
							if (Pass==1)
							{
/*								strcpy(TempStr2,popstr());
								strcpy(TempStr,popstr());
								strcat(TempStr,TempStr2);
								pushstr(TempStr); */
							}
						}
						SrcPtr++;
					}
				}
			}
			else
			{
				if ((SrcBuff[SrcPtr]<LastFunc)||(FnktVars[-SrcBuff[SrcPtr]-1]==0xaa))
				{
					printf("\nError: Unknown function %04x, ",SrcBuff[SrcPtr]);
					if ((Pass==1)||(Trace==0)) printf("aborting...\n");
					else printf("avoiding...\n");
					return(1);
				}

				if (Pass==1)
				{
					FnktUsed[-SrcBuff[SrcPtr]-1]++;
					if (fnktout(-SrcBuff[SrcPtr]-1)!=0)
					{
						TrashFunc=SrcBuff[SrcPtr];
						TrashFlag=1;
					}
					else if ((TrashFunc!=0)&&(fnktout(-TrashFunc-1)==0)) TrashFunc=0;
				}
				SrcPtr++;
			}
		}

		SrcPtr++;
		if (Pass==1)
		{
			strcpy(TempStr2,TransExp(AktExp));
			strcpy(TempStr,popstr());
			strcat(TempStr,TempStr2);
			pushstr(TempStr);
		}
	}

	ExpCount=ExpTemp+1;
	return(0);
}

// read vars + constants from source file

void ReadVars(int varCount)
{
	int varDims[3],varType,varDim,varBuff,i,j,k;

	k=varCount;

	if ((VarDefs=calloc(varCount,sizeof(PPEVar)))==NULL)
	{
		printf("\nError: Not enough RAM, aborting...\n"); exit(1);
	}

	varCount++;
	while (varCount>0x01)
	{

		fread(Buff,1,11,SrcFile);
		if (version>=300) DeCode(Buff,11);

		varCount=Buff[1]*256+Buff[0];
		varDim=Buff[2];
		varDims[0]=Buff[4]*256+Buff[3];
		varDims[1]=Buff[6]*256+Buff[5];
		varDims[2]=Buff[8]*256+Buff[7];
		varType=Buff[9];

		VarDefs[varCount-1].Number=0;
		VarDefs[varCount-1].Func=0;
		VarDefs[varCount-1].Type=varType;
		VarDefs[varCount-1].Dim=varDim;
		VarDefs[varCount-1].Dims[0]=varDims[0];
		VarDefs[varCount-1].Dims[1]=varDims[1];
		VarDefs[varCount-1].Dims[2]=varDims[2];
		VarDefs[varCount-1].Content=0;
		VarDefs[varCount-1].Content2=0;
		VarDefs[varCount-1].StrPtr=NULL;
		VarDefs[varCount-1].Flag=0;
		VarDefs[varCount-1].LFlag=0;
		VarDefs[varCount-1].FFlag=0;

		if (varType==7)
		{
			fread(&varBuff,1,2,SrcFile);
			if ((VarDefs[varCount-1].StrPtr=malloc(varBuff))==NULL)
			{
				printf("\nError: Not enough RAM, aborting...\n"); exit(1);
			}
			fread((VarDefs[varCount-1].StrPtr),1,varBuff,SrcFile);
			if (version>=300) DeCode(VarDefs[varCount-1].StrPtr,varBuff);
		}
		else if (varType==15)	//FUNCTION
		{
			fread(Buff,1,12,SrcFile);
			DeCode(Buff,12);

			VarDefs[varCount-1].Args=Buff[4];
			VarDefs[varCount-1].TotalVar=Buff[5]-1;
			VarDefs[varCount-1].Start=Buff[7]*256+Buff[6];
			VarDefs[varCount-1].FirstVar=Buff[9]*256+Buff[8];
			VarDefs[varCount-1].ReturnVar=Buff[11]*256+Buff[10];
		}
		else if (varType==16)	//PROCEDURE
		{
			fread(Buff,1,12,SrcFile);
			DeCode(Buff,12);

			VarDefs[varCount-1].Args=Buff[4];
			VarDefs[varCount-1].TotalVar=Buff[5];
			VarDefs[varCount-1].Start=Buff[7]*256+Buff[6];
			VarDefs[varCount-1].FirstVar=Buff[9]*256+Buff[8];
			VarDefs[varCount-1].ReturnVar=Buff[11]*256+Buff[10];
		}
		else
		{
			if (version==100)
			{
				fread(Buff,1,4,SrcFile);
				fread(&VarDefs[varCount-1].Content,1,4,SrcFile);
			}
			else if (version<300)
			{
				fread(Buff,1,4,SrcFile);
				fread(&VarDefs[varCount-1].Content,1,8,SrcFile);
			}
			else
			{
				fread(Buff,1,12,SrcFile);
				DeCode(Buff,12);
				VarDefs[varCount-1].Content=*(long*) &Buff[4];
				VarDefs[varCount-1].Content2=*(long*) &Buff[8];
			}
		}
	}

	while (k>=0)
	{
	switch (VarDefs[k].Type) {
	 case 15: {
			  VarDefs[VarDefs[k].ReturnVar-1].FFlag=1;
			  j=0;
			  for (i=VarDefs[k].FirstVar;i<VarDefs[k].TotalVar+VarDefs[k].ReturnVar;i++)
			  {
				VarDefs[i].LFlag=1;
				if (j<VarDefs[k].Args) VarDefs[i].Flag=1;
				if (i!=VarDefs[k].ReturnVar-1) VarDefs[i].Number=(++j);
			  }
			  } break;
	 case 16: {
			  j=0;
			  for (i=VarDefs[k].FirstVar;i<VarDefs[k].TotalVar+VarDefs[k].Args+VarDefs[k].FirstVar;i++)
			  {
				VarDefs[i].LFlag=1;
				if (j<VarDefs[k].Args)	VarDefs[i].Flag=1;
				VarDefs[i].Number=(++j);
			  }
			  } break;
	 default: break;
	 }
	k--;
	}
}

// reads the (open) sourcefile

word ReadSource(void)
{
	int i;
	word CodeSize, RealSize;
	word* SrcBuff2;
	long curpos;

	fread(Buff,48,1,SrcFile);
	if (strstr(Buff,"PCBoard Programming Language Executable") == NULL)
	{
		printf("\nError: %s is not a PPE, aborting...\n",SrcName); exit(1);
	}
	version=((Buff[40]&15)*10+(Buff[41]&15))*100+(Buff[43]&15)*10+(Buff[44]&15);
	Buff[39]=0;
	if (Symbol==0) fprintf(DstFile,";%s %d.%02d detected.\n",Buff,version/100,version%100);
	if (version>LastPPLC)
	{
		printf("\n%s %d.%02d detected.\n",Buff,version/100,version%100);
		printf("PPLD supports only versions up to 3.30, expect some errors !\n");
		if (Symbol==0) fprintf(DstFile,";PPLD supports only versions up to 3.30, expect some errors !\n");
	}

	MemLeft=coreleft();

	fread(&maxVar,1,2,SrcFile);
	if (maxVar!=0) ReadVars(maxVar);

	fread(&CodeSize,1,2,SrcFile);

	curpos=ftell(SrcFile);
	fseek(SrcFile,0,SEEK_END);
	RealSize=(word)ftell(SrcFile)-curpos;
	fseek(SrcFile,curpos,SEEK_SET);

	if (((SrcBuff=malloc(RealSize))==NULL)||((ValidBuff=malloc(CodeSize))==NULL))
	{
		printf("\nError: Not enough RAM, aborting...\n");
		exit(1);
	}
	for (i=0;i<CodeSize/2;i++) ValidBuff[i]=1;

	fread(SrcBuff,RealSize,1,SrcFile);
	if (version>=300)
	{
		DeCode((byte*)SrcBuff,RealSize);

		if (RealSize!=CodeSize)
		{
			if ((SrcBuff2=malloc(CodeSize))==NULL)
			{
				printf("\nError: Not enough RAM, aborting...\n");
				exit(1);
			}
			DeCode2((byte*)SrcBuff,(byte*)SrcBuff2,RealSize,CodeSize);
			SrcBuff=SrcBuff2;
		}
	}

	CodeSize-=2;       //forget the last END
	return(CodeSize);
}

// clear some decompile data-tables

void InitDecomp (void)
{
	int i;

	for(i=0;i<200;i++)
	{
		StatUsed[i]=0;
		FnktUsed[i]=0;
	}

	for(i=0;i<1000;i++)
	{
		LabelUsed[i]=-1;
		FuncUsed[i].Label=-1;
	}
}

// show wheel for decompilation progress

void ShowWheel (void)
{
	PassWheel++;
	PassWheel&=3;
	switch (PassWheel) {
	 case 0: printf("\b/"); break;
	 case 1: printf("\b-"); break;
	 case 2: printf("\b\\"); break;
	 case 3: printf("\b|"); break;
	}
}

// fill ValidBuff i to j with 0

void FillValid (int i, int j)
{
	int k;
	for (k=i;k<j;k++) ValidBuff[k]=0;
}

int setifptr (int i)
{
	if ((SrcBuff[SrcBuff[SrcPtr]/2-2]==0x0007) &&
		(SrcBuff[SrcBuff[SrcPtr]/2-1]/2==i))
		{
		 SrcBuff[i]=0;
		 i=SrcBuff[SrcPtr]/2-2;
		}
	else i=-5;
	return(i);
}

// do decompile pass 1

int DoPass1 (word CodeSize)
{
	int PrevStat=0, LastPoint;
	int IfPtr;

	AktStat=0;
	NextLabel=0;
	NextFunc=0;
	SrcPtr=0;
	IfPtr=-5;

	do {

		LastPoint=SrcPtr;

More:   if ((SrcPtr>=CodeSize/2)||(ValidBuff[SrcPtr]==0))
		{
			FillValid(LastPoint,SrcPtr);
			if (Trace) goto Trap;
			return(0);
		}

		ShowWheel();

		PrevStat=AktStat;
		if (SrcPtr==IfPtr) SrcPtr+=2;

		AktStat=SrcBuff[SrcPtr];

		if ((AktStat>LastStat)||(StatVars[AktStat]==0xaa))
		{
			printf("\nError: Unknown statement %04x, ",AktStat);
			if (Trace) printf("avoiding...\n");
			else
			{
				printf("aborting...\n");
				return(1);
			}
			goto Trap;
		}

		switch (StatVars[AktStat]) {
		 case 0xf6: SrcPtr+=2;
					AktProc=SrcBuff[SrcPtr-1]-1;
					VarDefs[AktProc].Flag=1;
					funcin(VarDefs[AktProc].Start,AktProc);
					pushlabel(VarDefs[AktProc].Start);
					if (getexpr(VarDefs[AktProc].Args,0)) goto Trap; break;
		 case 0xf7: if (getexpr(0x01,0)) goto Trap;
					VarDefs[SrcBuff[SrcPtr]-1].Flag=1;
					if (getexpr(0x01,0)) goto Trap; break;
		 case 0xf8: if (getexpr(0x03,0)) goto Trap;
					VarDefs[SrcBuff[SrcPtr]-1].Flag=1;
					SrcPtr++; break;
		 case 0xf9: VarDefs[SrcBuff[SrcPtr+1]-1].Flag=1;
					VarDefs[SrcBuff[SrcPtr+2]-1].Flag=1;
					SrcPtr+=3; break;
		 case 0xfe: if (getexpr(SrcBuff[++SrcPtr],0)) goto Trap; break;
		 case 0xfa: VarDefs[SrcBuff[SrcPtr+2]-1].Flag=1;
					SrcPtr+=2;
					if (getexpr(SrcBuff[SrcPtr-1]-1,0)) goto Trap; break;
		 case 0xfc: if (getexpr(SrcBuff[++SrcPtr]|0xf00,0)) goto Trap; break;
		 case 0xfd: SrcPtr++;
					labelin(SrcBuff[SrcPtr]);
					SrcPtr++; break;
		 case 0xff: IfPtr=SrcPtr;
					if (getexpr(0x01,0)) goto Trap;
					IfPtr=setifptr(IfPtr);
					SrcPtr++; break;
		  default : if (getexpr((StatVars[AktStat]&0xf0)*16+(StatVars[AktStat]&0x0f),0)) goto Trap;
					break;
		}

		if (!Trace) goto More;

		switch (AktStat) {
		 case 0x0001:; //END
		 case 0x002a:; //RETURN
		 case 0x00a9:; //ENDPROC
		 case 0x00ab:; //ENDFUNC
		 case 0x003a:FillValid(LastPoint,SrcPtr); //STOP
					 LastPoint=SrcPtr;
					 if (PrevStat==0x000b) goto More;
					 break;
		 case 0x0029:FillValid(LastPoint,SrcPtr); //GOSUB
					 LastPoint=SrcPtr;
					 pushlabel(SrcBuff[SrcPtr-1]);
					 goto More;
		 case 0x0007:FillValid(LastPoint,SrcPtr); //GOTO
					 LastPoint=SrcPtr;
					 pushlabel(SrcBuff[SrcPtr-1]);
					 if (PrevStat==0x000b) goto More;
					 break;
		 case 0x000b:FillValid(LastPoint,SrcPtr); //IF
					 LastPoint=SrcPtr;
					 pushlabel(SrcBuff[SrcPtr-1]);
					 goto More;
			 default: goto More;
		}

	Trap:

	} while (((SrcPtr=poplabel()/2)!=0xffff)&&(SrcPtr<=(CodeSize/2)));

	return(0);
}

// do decompile pass 2

int DoPass2(word CodeSize)
{
	int PrevStat, IfPtr;

	AktStat=-1;
	NextLabel=0;
	NextFunc=0;
	SrcPtr=0;
	TrashFlag=0;
	IfPtr=-1;

	TrashFlag2=0;
	while (SrcPtr < CodeSize/2)
	{
		ShowWheel();

		PrevStat=AktStat;
		StackPtr=0;
		if (SrcPtr==IfPtr) SrcPtr+=2;

		funcout(SrcPtr*2);
		labelout(SrcPtr*2);

		if (ValidBuff[SrcPtr])
		{
			SrcPtr++;
			continue;
		}

		AktStat=SrcBuff[SrcPtr];

		if ((AktStat>LastStat)||(StatVars[AktStat]==0xaa))
		{
			printf("\nError: Unknown statement %04x, aborting...\n",AktStat);
			return(1);
		}

		StatUsed[AktStat]++;

		if (StatVars[PrevStat]!=0xff)
		{
			if (Symbol==1) SymLine(SrcPtr*2);
			fprintf(DstFile,"    ");
		}
		fprintf(DstFile,"%s",StatNames[AktStat]);

		if (AktStat!=0xa8) fprintf(DstFile," ");

		switch (StatVars[AktStat]) {
		 case 0xf6: SrcPtr+=2;
					AktProc=SrcBuff[SrcPtr-1]-1;
					fprintf(DstFile,"%03d(",VarDefs[AktProc].Number);
					if (getexpr(VarDefs[SrcBuff[SrcPtr-1]-1].Args,0)) return(1);
					fprintf(DstFile,popstr());
					fprintf(DstFile,")"); break;
		 case 0xf7: if (getexpr(0x01,0)) return(1);
					fprintf(DstFile,",%s,",varout(SrcBuff[SrcPtr]));
					if (getexpr(0x01,0)) return(1);
					fprintf(DstFile,popstr()); break;
		 case 0xf8: if (getexpr(0x03,0)) return(1);
					fprintf(DstFile,popstr());
					fprintf(DstFile,",%s",varout(SrcBuff[SrcPtr]));
					SrcPtr++; break;
		 case 0xf9: fprintf(DstFile,"%s,",varout(SrcBuff[SrcPtr+1]));
					fprintf(DstFile,"%s",varout(SrcBuff[SrcPtr+2]));
					SrcPtr+=3; break;
		 case 0xfe: if (getexpr(SrcBuff[++SrcPtr],0)) return(1);
					fprintf(DstFile,popstr()); break;
		 case 0xfa: fprintf(DstFile,"%s,",varout(SrcBuff[SrcPtr+2]));
					SrcPtr+=2;
					if (getexpr(SrcBuff[SrcPtr-1]-1,0)) return(1);
					fprintf(DstFile,popstr()); break;
		 case 0xfc: if (getexpr(SrcBuff[++SrcPtr]|0xf00,0)) return(1);
					fprintf(DstFile,popstr()); break;
		 case 0xfd: SrcPtr++;
					fprintf(DstFile,"LABEL%03d",labelnr(SrcBuff[SrcPtr]));
					SrcPtr++; break;
		 case 0xff: IfPtr=SrcPtr;
					fprintf(DstFile,"(");
					if (getexpr(0x001,0)) return(1);
					fprintf(DstFile,popstr());
					fprintf(DstFile,") ");
					IfPtr=setifptr(IfPtr);
					SrcPtr++; break;
		  default : if (getexpr((StatVars[AktStat]&0xf0)*16+(StatVars[AktStat]&0x0f),0)) return(1);
					fprintf(DstFile,popstr());
					break;
		}

		if (StatVars[AktStat]!=0xff)
		{
			if (TrashFlag!=0)
			{
				fprintf(DstFile,"   ; PPLC bug detected");
				TrashFlag2++;
				TrashFlag=0;
			}
			fprintf(DstFile,"\n");
		}

		switch (AktStat) {
		 case 0x0001: ; //END
		 case 0x002a: ; //RETURN
		 case 0x003a: if (Symbol==1) SymLine(SrcPtr*2);
					  fprintf(DstFile,"\n"); //STOP
					  break;
		 case 0x00a9: ; //ENDPROC
		 case 0x00ab: FuncFlag=0; ProcFlag=0; //ENDFUNC
					  if (Symbol==1) SymLine(SrcPtr*2);
					  fprintf(DstFile,"\n");
					  break;
		 }

	}
	labelout(SrcPtr*2);
	return(0);
}

// output collected vars

void DumpVars(int maxVar)
{
	int i=0,cVars=0,cConst=0,cFunc=0,cProc=0;

	if ((VarDefs[0].Type==0)&&(VarDefs[1].Type==0)&&(VarDefs[2].Type==0)
	   &&(VarDefs[3].Type==0)&&(VarDefs[4].Type==2)&&(VarDefs[5].Type==4)
	   &&(VarDefs[6].Type==4)&&(VarDefs[7].Type==4)&&(VarDefs[8].Type==7)
	   &&(VarDefs[9].Type==7)&&(VarDefs[10].Type==7)&&(VarDefs[11].Type==7)
	   &&(VarDefs[12].Type==7)&&(VarDefs[13].Type==7)&&(VarDefs[14].Type==7)
	   &&(VarDefs[15].Type==0)&&(VarDefs[16].Type==0)&&(VarDefs[17].Type==0)
	   &&(VarDefs[18].Type==7)&&(VarDefs[19].Type==7)&&(VarDefs[20].Type==7)
	   &&(VarDefs[21].Type==7)&&(VarDefs[22].Type==2)&&(VarDefs[20].Dims[0]==5))
	   UVarFlag=1;

	if ((UVarFlag==1)&&(version>=300))
	{
		if (!((VarDefs[23].Type==4)&&(VarDefs[23].Dims[0]==16))) UVarFlag=0;
	}

	initstack();

	if (Symbol==0)
	{
		fprintf(DstFile,";\n;Source Code:\n");
		fprintf(DstFile,";------------------------------------------------------------------------------\n\n");
	}

	while (i<maxVar)
	{
		if ((i>0x16)||(UVarFlag!=1))
		{
			if (VarDefs[i].LFlag==0)
			{
				switch (VarDefs[i].Type) {
				 case 15: if ((!Trace)||(VarDefs[i].Flag==1))
						  {
							VarDefs[i].Number=(++cFunc);
							VarDefs[VarDefs[i].ReturnVar-1].Number=cFunc;
							if (Symbol==0)
							{
								fprintf(DstFile,"    DECLARE ");
								outputFunc(i);
								fprintf(DstFile,"\n");
							}
						  }
						  break;
				 case 16: if ((!Trace)||(VarDefs[i].Flag==1))
						  {
							VarDefs[i].Number=(++cProc);
							if (Symbol==0)
							{
								fprintf(DstFile,"    DECLARE ");
								outputProc(i);
								fprintf(DstFile,"\n");
							}
						  }
						  break;
				 default: if (VarDefs[i].Flag==0) VarDefs[i].Number=(++cConst);
						  else
						  {
							VarDefs[i].Number=(++cVars);
							if (Symbol==0)
							{
								fprintf(DstFile,"    %-10s",TypeNames[VarDefs[i].Type]);
								fprintf(DstFile," VAR%03d",cVars);

								switch (VarDefs[i].Dim) {
								 case 1:fprintf(DstFile,"(%d) ",	   VarDefs[i].Dims[0]); break;
								 case 2:fprintf(DstFile,"(%d,%d) ",   VarDefs[i].Dims[0],
										VarDefs[i].Dims[1]); break;
								 case 3:fprintf(DstFile,"(%d,%d,%d) ",VarDefs[i].Dims[0],
										VarDefs[i].Dims[1],
										VarDefs[i].Dims[2]); break;
								}
								fprintf(DstFile,"\n");
							}
							else SymVar(i);
						  }

				}
			}
		}
		i++;
	}

	if (Symbol==0) fprintf(DstFile,"\n;------------------------------------------------------------------------------\n\n");
}

// output used statements

void DumpStats(void)
{
	int i;

	fprintf(DstFile,"\n;Statements used:\n;\n");

	for(i=0;i<256;i++)
		if (StatUsed[i]>0) fprintf(DstFile,";  %4d %s\n",StatUsed[i],StatNames[i]);
}

// output used functions

void DumpFuncs(void)
{
	int i;

	fprintf(DstFile,";\n;Functions used:\n;\n");

	for(i=0;i<512;i++)
		if (FnktUsed[i]>0) fprintf(DstFile,";  %4d %s\n",FnktUsed[i],FnktNames[i]);
}

// output local vars

void DumpLocs(int func)
{
	int i,MaxVar;
	int j=0;

	StackPtr=0;

	if (VarDefs[func].Type==15)
	{
		i=VarDefs[func].ReturnVar;
		MaxVar=VarDefs[func].ReturnVar+VarDefs[func].TotalVar;
	}
	else
	{
		i=VarDefs[func].FirstVar+VarDefs[func].Args;
		MaxVar=VarDefs[func].FirstVar+VarDefs[func].TotalVar; //+1;
	}

	while (i<MaxVar)
	{
		if (VarDefs[i].Flag==1)
		{
			VarDefs[i].Func=func;
			if (Symbol==0)
			{
			fprintf(DstFile,"\n");
			fprintf(DstFile,"    %-10s",TypeNames[VarDefs[i].Type]);
			fprintf(DstFile," LOC%03d",VarDefs[i].Number);
			switch (VarDefs[i].Dim) {
			 case 1: fprintf(DstFile,"(%d) ",	   VarDefs[i].Dims[0]); break;
			 case 2: fprintf(DstFile,"(%d,%d) ",   VarDefs[i].Dims[0],
												   VarDefs[i].Dims[1]); break;
			 case 3: fprintf(DstFile,"(%d,%d,%d) ",VarDefs[i].Dims[0],
												   VarDefs[i].Dims[1],
												   VarDefs[i].Dims[2]); break;
				}
			}
			else SymVar(i);

		}
		i++;j++;
	}
	if (j>0) fprintf(DstFile,"\n");
}

// output function declaration

void outputFunc(int func)
{
	int i,j;
	if (Symbol==1) SymFunc(VarDefs[func].Start,func);
	fprintf(DstFile,"FUNCTION FUNC%03d(",VarDefs[func].Number);
	j=VarDefs[func].FirstVar;
	for (i=0;i<VarDefs[func].Args;i++)
	{
		if (i!=0) fprintf(DstFile,",");
		fprintf(DstFile,"%s",TypeNames[VarDefs[j].Type]);
		VarDefs[j].Func=func;
		fprintf(DstFile," LOC%03d",VarDefs[j].Number);
		if (Symbol==1) SymVar(j);
		j++;
	}
	fprintf(DstFile,") %s",TypeNames[VarDefs[j].Type]);
}

// output procedure declaration

void outputProc(int proc)
{
	int i,j;
	if (Symbol==1) SymFunc(VarDefs[proc].Start,proc);
	fprintf(DstFile,"PROCEDURE PROC%03d(",VarDefs[proc].Number);
	j=VarDefs[proc].FirstVar;
	for (i=0;i<VarDefs[proc].Args;i++)
	{
		if (i!=0) fprintf(DstFile,",");
		if ((VarDefs[proc].ReturnVar>>i)&1)
		{
			fprintf(DstFile,"VAR ");
		}
		fprintf(DstFile,"%s",TypeNames[VarDefs[j].Type]);
		VarDefs[j].Func=proc;
		fprintf(DstFile," LOC%03d",VarDefs[j].Number);
		if (Symbol==1) SymVar(j);
		j++;
	}
	fprintf(DstFile,")");

}

void DeCode(byte* block,word fullsize)
{
	word size;

	block-=0x07ff;

	do
	{
		if (fullsize<0x0800)
		{
			size=fullsize;
			fullsize=0;
		}
		else
		{
			size=0x07ff;
			fullsize-=0x07ff;
		}

		block+=0x07ff;

		asm {
			push si; push di; push ds;

			lds  si,dword ptr block
			les  di,dword ptr block
			cld
			mov  bx,0xdb24
			mov  dx,word ptr size
			shr  dx,1
			push bp
		}
		Jump1:
		asm {
			or	 dx,dx
			je   Jump2
			lodsw
			mov  bp,ax
			mov  cl,bl
			add  cl,dl
			ror  ax,cl
			xor  al,dl
			xor  ah,dl
			xor  ax,bx
			stosw
			mov  bx,bp
			dec  dx
			jmp  Jump1
		}
		Jump2:
		asm {
			pop  bp
			test word ptr size,1
			je   Jump3
			lodsb
			xor  al,bl
			ror  al,cl
			stosb
		}
		Jump3:
		asm {
			pop ds; pop di; pop si;
		}

		if ((size==0x07ff)&&(block[0x07fe]==0))
		{
			block++;
			fullsize--;
		}

	} while (fullsize>0);
}

void DeCode2(byte* block1,byte* block2,word size, word size2)
{
	word i=0,j=0;

	while ((i<size)&&(j<size2))
	{
		block2[j++]=block1[i++];
		block2[j++]=block1[i++];
		if (block2[j-1]==0)
		{
/*			if (block1[i]>15)
			{
				printf("\nError: Decrypting failed, aborting...\n");
				exit(1);
			}
*/
			while (block1[i]>1)
			{
				block2[j++]=0;
				block1[i]--;
			}
			i++;
		}
		else
		{
			if (block1[i]==0)
			{
				block2[j]=0;
				i++; j++;

/*				if (block1[i]>15)
				{
					printf("\nError: Decrypting failed, aborting...\n");
					exit(1);
				}
*/

				while (block1[i]>1)
				{
					block2[j++]=0;
					block1[i]--;
				}
				i++;
			}
		}
	}
}
